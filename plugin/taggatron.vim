if !exists("g:tagcommands")
    let g:tagcommands = {}
endif
if !exists("g:tagdefaults")
    let g:tagdefaults = ""
endif
if !exists("g:taggatron_verbose")
    let g:taggatron_verbose = 0
endif

autocmd BufWritePost * call taggatron#CheckCommandList(0)
command! TagUpdate call taggatron#CheckCommandList(1)
command! -nargs=1 SetTags call taggatron#SetTags(<f-args>)

function! taggatron#SetTags(tags)
    call taggatron#debug("Setting tag files: ".a:tags)
    exec "set tags=".a:tags
    let g:tagdefaults = a:tags
endfunction

function! taggatron#CheckCommandList(forceCreate)
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
