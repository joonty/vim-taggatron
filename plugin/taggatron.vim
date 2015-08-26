" Initialise script default values
let s:taggatron_enabled = 1
let s:taggatron_verbose = 0
let s:taggatron_multicommands = 0
let s:tagdefaults = ''
let s:tagcommands = {}
let s:tagcommand_defaults = {
            \ "cmd": "ctags-exuberant",
            \ "args": "",
            \ "filesappend": "**"
            \ }

" Function Declarations
" =====================
"
" This section is used minimize memory foot print of the idle plugin and to 
" speed up loading times. All functions required to initialise the plugin are 
" declared below, delaying the load of `autoload/taggatron.vim` file until the 
" first time the plugin is used.

""
" Add a file to the list of local tags
"
" This function is used to add user supplied file to the list of local tags. 
" Before being added, the filename is converted to the absolute path to file 
" and is only added if that file is not already on the list.
"
" @param list|string files A file or a list of files to be added
"
function! taggatron#SetTags(files)
    " Define local support variables
    let l:files = type(a:files) == 1 ? [a:files] : a:files
    let l:tagfiles = []

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
        call add(l:tagfiles, fnamemodify(l:tagfile, ':p'))
    endfor

    " Process all tag files one by one
    for l:file in l:files
        " Skip non-existent and unreadable file
        if !filereadable(l:file)
            call taggatron#debug("Skipping unreadable tag file: " . l:file)
            continue
        endif

        " Ensure absolute path to the current file
        let l:file = fnamemodify(l:file, ':p')

        " Only add current file to tags if it hasn't been already found
        if index(l:tagfiles, l:file) == -1
            call taggatron#debug("Adding tag file:" . l:file)
            exec "setlocal tags+=" . l:file
        endif
    endfor
endfunction

""
" Fetch a scoped value of an option
"
" Determine a value of an option based on user configuration or pre-configured 
" defaults. A user can configure an option by defining it as a buffer variable 
" or as a global (buffer vars override globals). Default value can be provided 
" by defining a script variable for the whole file or a function local (local 
" vars override script vars). When all else fails, falls back the supplied 
" default value,  if one is supplied.
"
" @param string option Scope-less name of the option
" @param mixed a:1 An option default value for the option
"
function! taggatron#get(option, ...)
    for l:scope in ['b', 'g', 'l', 's']
        if exists(l:scope . ':' . a:option)
            return eval(l:scope . ':' . a:option)
        endif
    endfor

    if a:0 > 0
        return a:1
    endif

    call taggatron#error('Invalid or undefined option: ' . a:option)
endfunction

""
" Show user an error message
"
" Pre-format supplied message as an Error and display it to the user. All 
" messages are saved to message-history and are accessible via `:messages`.
"
" @param string message A message to be displayed to the user
"
function! taggatron#error(message)
    echohl Error | echomsg a:message | echohl None
endfunction

""
" Show user a debug message
"
" Echo supplied message to the user if verbose mode is enabled.  All messages 
" are saved to message-history and can be reviewed with :messages command.
"
" @param string message A message to be displayed to the user
"
function! taggatron#debug(message)
    " Do nothing if verbose mode is disabled
    if taggatron#get('taggatron_verbose') == 0
        return
    endif

    echomsg a:message
endfunction

" Executable code
" ===============

" Initialise taggatron auto-commands
augroup Taggatron
    autocmd!
    autocmd BufNew,BufRead * call taggatron#SetTags(taggatron#get('tagdefaults'))
    autocmd BufWritePost * call taggatron#CheckCommandList(0)
augroup END

" Initialise taggatron commands
command! TagUpdate call taggatron#CheckCommandList(1)
command! -nargs=1 SetTags call taggatron#SetTags(<f-args>)
