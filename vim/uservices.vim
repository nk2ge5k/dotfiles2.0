
if !exists('g:term_channel_id')
    let g:term_channel_id = -1
endif

if !exists('g:term_use_tmux')
    let g:term_use_tmux = 0
endif

function! s:TermOpen(cwd)

    " TODO(nk2ge5k): switch between vsplit and split
    new

    let g:term_channel_id = termopen(&shell, {'cwd': a:cwd})
endfunction

function! s:SendKeys(cmd)
    call chansend(g:term_channel_id, [a:cmd, ""])
endfunction

function! s:RunCommand(cmd, ...)
    if g:term_use_tmux
        return tmux#SendKeys(cmd, get(a:000, 0, getcwd()))
    endif

    try
        " canceling previous job
        call s:SendKeys("\<c-c>")
        call s:SendKeys(a:cmd)
    catch
        call s:TermOpen(get(a:000, 0, getcwd()))
        call s:SendKeys(a:cmd)
    endtry
endfunction

function! s:ExtractUservicesRootDir()
    if exists('w:uservices_dir')
        return w:uservices_dir
    endif

    let previous = ''

    let root = getcwd()
    while root !=# previous
        if fnamemodify(root, ':t') ==# 'uservices'
            let w:uservices_dir = root
            return w:uservices_dir
        endif

        let previous = root
        let root = fnamemodify(root, ':h')
    endwhile

    return ''
endfunction

function! s:ExtractProjectDir()

    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let root = getcwd()

    while root !=# previous && root !=# uservices_dir
        let service_yaml = substitute(root, '[\/]$', '', '') . '/service.yaml'
        let type = getftype(service_yaml)
        if type ==# 'file'
            return root
        endif

        let library_yaml = substitute(root, '[\/]$', '', '') . '/library.yaml'
        let type = getftype(library_yaml)
        if type ==# 'file'
            return root
        endif

        let previous = root
        let root = fnamemodify(root, ':h')
    endwhile

endfunction

function! s:ExtractServiceName(uservices_dir)
    let previous = ''
    let root = getcwd()

    while root !=# previous && root !=# a:uservices_dir
        let service_yaml = substitute(root, '[\/]$', '', '') . '/service.yaml'
        let type = getftype(service_yaml)
        if type ==# 'file'
            return fnamemodify(root, ':t')
        endif

        let previous = root
        let root = fnamemodify(root, ':h')
    endwhile

    return ''
endfunction

function! s:ExtractLibraryName(uservices_dir)
    let previous = ''
    let root = getcwd()

    while root !=# previous && root !=# a:uservices_dir
        let library_yaml = substitute(root, '[\/]$', '', '') . '/library.yaml'
        let type = getftype(library_yaml)
        if type ==# 'file'
            return fnamemodify(root, ':t')
        endif

        let previous = root
        let root = fnamemodify(root, ':h')
    endwhile

    return ''
endfunction

function! uservices#Cmake(...) abort

    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let service = get(a:000, 0, '')

    if empty(service)
        let service = s:ExtractServiceName(uservices_dir)
        if empty(service)

            let library = s:ExtractLibraryName(uservices_dir)
            if !empty(library)
                return s:RunCommand('make -B cmake-lib-' . library, uservices_dir)
            endif

            return 'echoerr ' . string('service name is required')
        endif
    endif

    return s:RunCommand('make -B cmake-' . service, uservices_dir)
endfunction

function! uservices#TestsAll(...) abort

    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let service = get(a:000, 0, '')

    if empty(service)
        let service = s:ExtractServiceName(uservices_dir)
        if empty(service)
            return 'echoerr ' . string('service name is required')
        endif
    endif

    let cmd = [
        \ 'make',
        \ 'testsuite-' . service,
        \ ]

    if exists('g:ucompile_procs')
        call add(cmd, 'NPROCS=' . g:ucompile_procs)
    endif
    let cmd = cmd + [ ';', 'tmux', 'display', 
                \ '"Test for service ' . service . ' fininshed"']

    return s:RunCommand(join(cmd, ' '), uservices_dir)
endfunction

function! uservices#TestFile(...) abort
    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let service = get(a:000, 0, '')

    if empty(service)
        let service = s:ExtractServiceName(uservices_dir)
        if empty(service)
            return 'echoerr ' . string('service name is required')
        endif
    endif

    let filename = expand('%:t')

    let cmd = [
        \ 'make',
        \ 'testsuite-' . service,
        \ ' PYTEST_ARGS="-k ' . filename . ' -vv"',
        \ ]

    if exists('g:ucompile_procs')
        call add(cmd, 'NPROCS=' . g:ucompile_procs)
    endif
    let cmd = cmd + [ ';', 'tmux', 'display',
                \ '"Test for file ' . filename . ' fininshed"']

    return s:RunCommand(join(cmd, ' '), uservices_dir)
endfunction

function! uservices#TestsuiteThis() abort
    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let service = s:ExtractServiceName(uservices_dir)
    if empty(service)
        return 'echoerr ' . string('could not detect service')
    endif

    let linenum = line('.')

    while linenum > 0
        if getline(linenum) =~ '^async def test_'
            break
        endif
        let linenum = linenum - 1
    endwhile

    if linenum == 1
        return 'echoerr ' . string('failed to find test function')
    end

    let line = getline(linenum)

    let start =  match(line, 'test_')
    if start < 0
        return 'echoerr ' .  string('failed to get test name')
    endif

    let end = match(line, '(', start)
    let name = line[start:end-1]

    let cmd = [
        \ 'make',
        \ 'testsuite-' . service,
        \ ' PYTEST_ARGS="-k ' . name . ' -vv"',
        \ ]

    if exists('g:ucompile_procs')
        call add(cmd, 'NPROCS=' . g:ucompile_procs)
    endif
    let cmd = cmd + [ ';', 'tmux', 'display',
                \ '"Test for function ' . name . ' fininshed"']

    return s:RunCommand(join(cmd, ' '), uservices_dir)
endfunction

function! uservices#GdbThis() abort
    let uservices_dir = s:ExtractUservicesRootDir()
    if empty(uservices_dir)
        return 'echoerr ' . string('cannot call outside uservices directory')
    endif

    let service = s:ExtractServiceName(uservices_dir)
    if empty(service)
        return 'echoerr ' . string('could not detect service')
    endif

    let linenum = line('.')

    while linenum > 0
        if getline(linenum) =~ '^async def test_'
            break
        endif
        let linenum = linenum - 1
    endwhile

    if linenum == 1
        return 'echoerr ' . string('failed to find test function')
    end

    let line = getline(linenum)

    let start =  match(line, 'test_')
    if start < 0
        return 'echoerr ' .  string('failed to get test name')
    endif

    let end = match(line, '(', start)
    let name = line[start:end-1]

    let cmd = [
        \ 'make',
        \ 'testsuite-gdb-' . service,
        \ ' PYTEST_ARGS="-k ' . name . ' -vv"',
        \ ]

    if exists('g:ucompile_procs')
        call add(cmd, 'NPROCS=' . g:ucompile_procs)
    endif

    return s:RunCommand(join(cmd, ' '), uservices_dir)
endfunction

" commands
command! -bang -nargs=? -range=-1 Testsuite exec uservices#TestsAll(<f-args>)
command! -bang -nargs=0 -range=-1 TestFunction exec uservices#TestsuiteThis()
command! -bang -nargs=0 -range=-1 GdbFunction exec uservices#GdbThis()
command! -bang -nargs=0 -range=-1 TestFile exec uservices#TestFile()
command! -bang -nargs=? -range=-1 BCmake exec uservices#Cmake(<f-args>)

noremap <leader>fa :Testsuite<CR>
noremap <leader>fi :TestFunction<CR>
noremap <leader>ff :TestFile<CR>
