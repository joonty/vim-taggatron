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

""
" Determine an option's value based on user configuration or a default value. 
"
" A user can configure an option by defining it as a buffer variable or as 
" a global (buffer vars override globals). Default value can be provided by 
" defining a script variable for the whole file or a function local variable 
" (local vars override script vars). When all else fails, a fallback default 
" value can by supplied as a second argument to the function.
"
function! taggatron#get(option, ...)
    for l:scope in ['b', 'g', 'l', 's']
        if exists(l:scope . ':'. a:option)
            return eval(l:scope . ':'. a:option)
        endif
    endfor

    if a:0 > 0
        return a:1
    endif

    call taggatron#error('Invalid or undefined option: ' . a:option)
endfunction

""
" Echo supplied messages to the user, pre-formatting it as an Error. All 
" messages are saved into message-history buffer and can be reviewed with 
" :messages command.
"
function! taggatron#error(str)
    echohl Error | echomsg a:str | echohl None
endfunction

""
" Echo supplied messages to the user but only of taggatron verbose mode has 
" been enabled. All messages are saved into message-history buffer and can be 
" reviewed with :messages command.
"
function! taggatron#debug(str)
    if taggatron#get('taggatron_verbose') == 1
        echomsg a:str
    endif
endfunction

" -- "

" Include global default tags
if exists('g:tagdefaults') && len(g:tagdefaults) > 0
    call taggatron#debug("Adding global default tags: ".g:tagdefaults)
    call taggatron#SetTags(g:tagdefaults)
endif

" Initialise taggatron auto-commands
augroup Templates
    autocmd!

    " Include buffer default tags
    autocmd BufNew,BufRead * if exists('b:tagdefaults') && len(b:tagdefaults) > 0 |
                \ call taggatron#debug("Adding buffer default tags: ".b:tagdefaults)
                \ call taggatron#SetTags(g:tagdefaults)
                \ endif

    " Create tags for the local file
    autocmd BufWritePost * call taggatron#CheckCommandList(0)
augroup END

" Initialise taggatron commands
command! TagUpdate call taggatron#CheckCommandList(1)
command! -nargs=1 SetTags call taggatron#SetTags(<f-args>)
