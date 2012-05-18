if !exists("g:tagcommands")
    let g:tagcommands = {"php":{"file":"~/php.tags"}}
endif
if !exists("g:taggen_verbose")
    let g:taggen_verbose = 1
endif

let s:taggen_cmd_entry = {"cmd":"ctags-exuberant","args":""}

au BufWritePost * call <SID>CheckCommandList()

function! <SID>CheckCommandList()
    call <SID>debug("Checking for tag command for this file type")
    let l:cmdset = get(g:tagcommands,&filetype)
    if len(l:cmdset) == 0
        call <SID>debug("No tag command for filetype " . &filetype)
    else
        call <SID>CreateTags(l:cmdset)
    endif

endfunction

function! <SID>CreateTags(cmdset)
    call <SID>debug("Creating tags")
    let l:cmdset = s:taggen_cmd_entry
    call extend(l:cmdset,a:cmdset)
    if get(l:cmdset,"file") == 0
        call <SID>error("Missing tag file destination from tag commands for file type ")
    endif
    if get(l:cmdset,"lang") == 0
        l:cmdset['lang'] = &filetype
    endif
    let l:cmdstr = l:cmdset['cmd'] . " " . l:cmdset["args"] . " --languages ".l:cmdset['lang']." -f ".l:cmdset['file']
    call <SID>debug(l:cmdstr)

endfunction

function! <SID>error(str)
    echohl Error | echo a:str | echohl None
endfunction

function! <SID>debug(str)
    if g:taggen_verbose == 1
        echo a:str
    endif
endfunction
