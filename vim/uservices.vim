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
                return tmux#SendKeys(uservices_dir, 'make -B cmake-lib-' . library)
            endif

            return 'echoerr ' . string('service name is required')
        endif
    endif

    return tmux#SendKeys(uservices_dir, 'make -B cmake-' . service)
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

    return tmux#SendKeys(uservices_dir, 'make testsuite-' . service)
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
    return tmux#SendKeys(uservices_dir, 'make testsuite-' . service .
                \ ' PYTEST_ARGS="-k ' . filename . ' -vv"')
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

    return tmux#SendKeys(uservices_dir, 'make testsuite-' . service .
                \ ' PYTEST_ARGS="-k ' . name . ' -vv"')
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

    return tmux#SendKeys(uservices_dir, 'make testsuite-gdb-' . service .
                \ ' PYTEST_ARGS="-k ' . name . ' -vv"')
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
