if !exists("g:tagcommands")
    let g:tagcommands = {}
endif
if !exists("g:tagdefaults")
    let g:tagdefaults = ""
endif
if !exists("g:taggatron_verbose")
    let g:taggatron_verbose = 0
endif
if !exists("g:taggatron_enabled")
    let g:taggatron_enabled = 1
endif

" Include all default tags
if len(g:tagdefaults) > 0
    call taggatron#debug("Adding default tags: ".g:tagdefaults)
    exec "setlocal tags+=".g:tagdefaults
endif

autocmd BufWritePost * call taggatron#CheckCommandList(0)
command! TagUpdate call taggatron#CheckCommandList(1)
command! -nargs=1 SetTags call taggatron#SetTags(<f-args>)

function! taggatron#SetTags(files)
    " Define local support variables
    let l:files = type(a:files) == 1 ? [a:files] : a:files
    let l:tagfiles = []
    let l:cwd = fnamemodify(getcwd(), ':p')

    " Fail if l:files is not a list
    if type(l:files) != 3
        call taggatron#error("Invalid tag file format, request to SetTags ignored.")
        return

    " Exit early if list is empty
    elseif empty(l:files)
        call taggatron#debug("No tag files defined, exiting early.")
        return
    endif

    " Create a list of all tag files currently loaded (absolute path)
    for l:tagfile in tagfiles()
        call add(l:tagfiles, fnamemodify(l:cwd.l:tagfile, ':p'))
    endfor

    " Process all tag files one by one
    for l:file in l:files
        " Skip non-existent and unreadable file
        if !filereadable(l:file)
            call taggatron#debug("Skipping non-existent or unreadable tag file: ".l:file)
            continue
        endif

        " Ensure absolute path to the current file
        let l:file = fnamemodify(l:file, ':p')

        " Only add current file to tags if it hasn't been already found
        if index(l:tagfiles, l:file) == -1
            call taggatron#debug("Adding tag file: ".l:file)
            exec "setlocal tags+=".l:file
        endif
    endfor
endfunction

function! taggatron#CheckCommandList(forceCreate)
    if g:taggatron_enabled != 1
        call taggatron#debug("Tag file generation disabled (taggatron_enabled: " . g:taggatron_enabled . ")")
        return
    endif

    let l:cwd = getcwd()
    call taggatron#debug("Current directory: ".l:cwd)
    if expand("%:p:h") =~ l:cwd . ".*"
        call taggatron#debug("Checking for tag command for this file type")
        let l:cmdset = get(g:tagcommands,&filetype)
        if l:cmdset is 0
            call taggatron#debug("No tag command for filetype " . &filetype)
        else
            call taggatron#CreateTags(l:cmdset,a:forceCreate)
        endif
    else
        call taggatron#debug("Not creating tags: file is not in current directory")
    endif
endfunction
