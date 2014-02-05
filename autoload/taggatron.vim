" Exit when already loaded (or "compatible" mode set)
if exists("g:loaded_taggatron") || &cp
    finish
endif
let g:loaded_taggatron= 1

" Initialise script default values
let s:taggatron_enabled = 1
let s:tagcommands = {}
let s:tagcommands_entry = {
            \ "cmd": "ctags-exuberant",
            \ "args": "",
            \ "filesappend": "**"
            \ }

""
" Check command options and initialise tag creation.
"
" Ensure that tags for the current file do need to be created, validate a set
" of current command line options, and create tags based on them.
"
" @param bool forceCreate A switch indicating if we want to update tags for 
" the current file only (0), or (re)create tags for all file under the path.
"
function! taggatron#CheckCommandList(forceCreate)
    " Exit early if taggatron is disabled
    if taggatron#get('taggatron_enabled') == 0
        call taggatron#debug('Tag file generation is disabled')
        return
    endif

    " Validate command options for the current file type
    call taggatron#debug('Checking for tag command for this file type')
    let l:cmdset = get(taggatron#get('tagcommands'), &filetype)

    " Do nothing  if tag command is missing
    if l:cmdset is 0
        call taggatron#debug('No tag command for filetype ' . &filetype)
        return
    endif

    " Identify project root directory (aka files)
    let l:cmdset['files'] = has_key(l:cmdset, 'files')
                \ ? fnamemodify(l:cmdset['files'], ':p')
                \ : fnamemodify(getcwd(), ':p')
    call taggatron#debug('Project root directory: ' . l:cmdset['files'])

    " Do nothing if the file is not inside the project directory
    if expand("%:p") !~ '^' . l:cmdset['files']
        call taggatron#debug('Not creating tags: file is not inside project root')
        return
    endif

    " Exit with an error if tag file argument is missing
    if !has_key(l:cmdset, 'tagfile')
        call taggatron#error('Missing tag file for file type ' . &filetype)
        return
    endif

    " Sanitize tagfile path
    let l:cmdset['tagfile'] = fnamemodify(l:cmdset['tagfile'], ':p')

    " Create tag file and ensure that it is in use by the editor
    call taggatron#CreateTags(l:cmdset, a:forceCreate)
    call taggatron#SetTags(l:cmdset['tagfile'])
endfunction

""
" Create tags as per command options
"
" This function is used to update tags for the current file via UpdateTags() 
" or to create a new tag file for tags collected from all files matching 
" a current/configured language under a specific path.
"
" @param dictionary cmdset A set of command options
"
function! taggatron#CreateTags(cmdset, forceCreate)
    call taggatron#debug('Creating tags for file type ' . &filetype)
    call taggatron#debug('Argument: ' . string(a:cmdset))
    call taggatron#debug('Default: ' . string(s:tagcommands_entry))

    " Initialise local support variables
    let l:cmdset = {}

    " Build up a set of command line options
    call extend(l:cmdset, s:tagcommands_entry)
    call extend(l:cmdset, a:cmdset)

    " Updated tag file and exit early
    if filereadable(l:cmdset['tagfile']) && a:forceCreate == 0
        call taggatron#debug('Updating tag file ' . l:cmdset['tagfile'])
        call taggatron#UpdateTags(l:cmdset['cmd'], l:cmdset['files'], l:cmdset['tagfile'])
        return
    endif

    " Append path suffix on top of the existing 'files' path
    if has_key(l:cmdset, 'filesappend')
        let l:cmdset['files'] = l:cmdset['files'] . l:cmdset['filesappend']
    endif

    " Auto-generate --languages command line argument
    let l:cmdset['args'] .= ' --languages='
                \ . (has_key(l:cmdset, 'lang') ? l:cmdset['lang'] : &filetype)

    " Auto-generate -f command line argument
    let l:cmdset['args'] .= ' -f ' . l:cmdset['tagfile']

    " Create a completed command line string from all available arguments
    let l:cmdstr = l:cmdset['cmd']
                \ . ' ' . l:cmdset['args']
                \ . ' ' . l:cmdset['files']

    " Execute tag creation command by passing it over to the system
    call taggatron#debug('Executing command: ' . l:cmdstr)
    call system(l:cmdstr)
endfunction

""""""""""""""""""
"  Auto tag v1.0 (modified)
"
""""""""""""""""""
"
" This file supplies automatic tag regeneration when saving files
" There's a problem with ctags when run with -a (append)
" ctags doesn't remove entries for the supplied source file that no longer exist
" so this script (implemented in python) finds a tags file for the file vim has
" just saved, removes all entries for that source file and *then* runs ctags -a

if has("python")
python << EEOOFF
import os
import string
import os.path
import fileinput
import sys
import vim
import time
import logging
from collections import defaultdict

# global vim config variables used (all are g:autotag<name>):
# name purpose
# maxTagsFileSize a cap on what size tag file to strip etc
# ExcludeSuffixes suffixes to not ctags on
# VerbosityLevel logging verbosity (as in Python logging module)
# CtagsCmd name of ctags command
# TagsFile name of tags file to look for
# Disabled Disable autotag (enable by setting to any non-blank value)
# StopAt stop looking for a tags file (and make one) at this directory (defaults to $HOME)
vim_global_defaults = dict(maxTagsFileSize = 1024*1024*7,
                           ExcludeSuffixes = "tml.xml.text.txt",
                           VerbosityLevel = logging.WARNING,
                           CtagsCmd = "ctags",
                           TagsFile = "tags",
                           Disabled = 0,
                           StopAt = 0)

# Just in case the ViM build you're using doesn't have subprocess
if sys.version < '2.4':
   def do_cmd(cmd, cwd):
      old_cwd=os.getcwd()
      os.chdir(cwd)
      (ch_in, ch_out) = os.popen2(cmd)
      for line in ch_out:
         pass
      os.chdir(old_cwd)

   import traceback
   def format_exc():
      return ''.join(traceback.format_exception(*list(sys.exc_info())))

else:
   import subprocess
   def do_cmd(cmd, cwd):
      p = subprocess.Popen(cmd, shell=True, stdout=None, stderr=None, cwd=cwd)

   from traceback import format_exc

def vim_global(name, kind = string):
   ret = vim_global_defaults.get(name, None)
   try:
      v = "g:autotag%s" % name
      exists = (vim.eval("exists('%s')" % v) == "1")
      if exists:
         ret = vim.eval(v)
      else:
         if isinstance(ret, int):
            vim.command("let %s=%s" % (v, ret))
         else:
            vim.command("let %s=\"%s\"" % (v, ret))
   finally:
      if kind == bool:
         ret = (ret not in [0, "0"])
      elif kind == int:
         ret = int(ret)
      elif kind == string:
         pass
      return ret

class VimAppendHandler(logging.Handler):
   def __init__(self, name):
      logging.Handler.__init__(self)
      self.__name = name
      self.__formatter = logging.Formatter()

   def __findBuffer(self):
      for b in vim.buffers:
         if b and b.name and b.name.endswith(self.__name):
            return b

   def emit(self, record):
      b = self.__findBuffer()
      if b:
         b.append(self.__formatter.format(record))

def makeAndAddHandler(logger, name):
   ret = VimAppendHandler(name)
   logger.addHandler(ret)
   return ret


class AutoTag:
   MAXTAGSFILESIZE = long(vim_global("maxTagsFileSize"))
   DEBUG_NAME = "autotag_debug"
   LOGGER = logging.getLogger(DEBUG_NAME)
   HANDLER = makeAndAddHandler(LOGGER, DEBUG_NAME)

   @staticmethod
   def setVerbosity():
      try:
         level = int(vim_global("VerbosityLevel"))
      except:
         level = vim_global_defaults["VerbosityLevel"]
      AutoTag.LOGGER.setLevel(level)

   def __init__(self):
      self.tags = defaultdict(list)
      self.excludesuffix = [ "." + s for s in vim_global("ExcludeSuffixes").split(".") ]
      AutoTag.setVerbosity()
      self.sep_used_by_ctags = '/'
      self.tags_file = str(vim_global("TagsFile"))
      self.count = 0
      self.stop_at = vim_global("StopAt")

   def setTagFile(self, f):
      self.tagfile = f

   def findTagFile(self, source):
      ret = None
      file = self.tagfile
      AutoTag.LOGGER.info('drive = "%s", file = "%s"', drive, file)
      tagsDir = os.path.join(drive, file)
      tagsFile = self.tagfile
      AutoTag.LOGGER.info('tagsFile "%s"', tagsFile)
      if os.path.isfile(tagsFile):
         st = os.stat(tagsFile)
         if st:
            size = getattr(st, 'st_size', None)
            if size is None:
               AutoTag.LOGGER.warn("Could not stat tags file %s", tagsFile)
            if size > AutoTag.MAXTAGSFILESIZE:
               AutoTag.LOGGER.info("Ignoring too big tags file %s", tagsFile)
         ret = (file, tagsFile)
      elif tagsDir and tagsDir == self.stop_at:
         AutoTag.LOGGER.info("Reached %s. Making one %s" % (self.stop_at, tagsFile))
         open(tagsFile, 'wb').close()
         ret = (file, tagsFile)
      elif not file or file == os.sep or file == "//" or file == "\\\\":
         AutoTag.LOGGER.info('bail (file = "%s")' % (file, ))
      return ret

   def normalizeSource(self, source, tagsDir):
      if not source:
         AutoTag.LOGGER.warn('No source')
         return
      if os.path.basename(source) == self.tags_file:
         AutoTag.LOGGER.info("Ignoring tags file %s", self.tags_file)
         return
      (base, suff) = os.path.splitext(source)
      if suff in self.excludesuffix:
         AutoTag.LOGGER.info("Ignoring excluded suffix %s for file %s", source, suff)
         return
      relativeSource = source[len(tagsDir):]
      if relativeSource[0] == os.sep:
         relativeSource = relativeSource[1:]
      if os.sep != self.sep_used_by_ctags:
         relativeSource = string.replace(relativeSource, os.sep, self.sep_used_by_ctags)
      return relativeSource

   def goodTag(self, line, excluded):
      if line[0] == '!':
         return True
      else:
         f = string.split(line, '\t')
         AutoTag.LOGGER.log(1, "read tags line:%s", str(f))
         if len(f) > 3 and f[1] not in excluded:
            return True
      return False

   def stripTags(self, tagsFile, sources):
      AutoTag.LOGGER.info("Stripping tags for %s from tags file %s", ",".join(sources), tagsFile)
      backup = ".SAFE"
      input = fileinput.FileInput(files=tagsFile, inplace=True, backup=backup)
      try:
         for l in input:
            l = l.strip()
            if self.goodTag(l, sources):
               print l
      finally:
         input.close()
         try:
            os.unlink(tagsFile + backup)
         except StandardError:
            pass

   def updateTagsFile(self, tagsDir, tagsFile, source):
      self.stripTags(tagsFile, [source])
      cmd = "%s -f %s -a " % (self.ctags_cmd, tagsFile)
      cmd += " '%s'" % source
      AutoTag.LOGGER.log(1, "%s: %s", tagsDir, cmd)
      do_cmd(cmd, tagsDir)

   def rebuildTagFiles(self):
      for ((tagsDir, tagsFile), sources) in self.tags.items():
         self.updateTagsFile(tagsDir, tagsFile, sources)
EEOOFF

function! taggatron#UpdateTags(ctagsCmd,workingDir,tagFile)
python << EEOOFF
try:
   tagsFile = vim.eval("a:tagFile")
   ( drive, tagsFileNoDrive ) = os.path.splitdrive(tagsFile)
   tagsDir = os.path.join(drive, os.path.dirname(tagsFile))
   at = AutoTag()
   source = vim.eval("expand(\"%:p\")")
   at.ctags_cmd = vim.eval('a:ctagsCmd')
   at.updateTagsFile(vim.eval("a:workingDir"),tagsFile,source)
except:
   logging.warning(format_exc())
EEOOFF
   if exists(":TlistUpdate")
      TlistUpdate
   endif
endfunction

function! AutoTagDebug()
   new
   file autotag_debug
   setlocal buftype=nowrite
   setlocal bufhidden=delete
   setlocal noswapfile
   normal 
endfunction

endif " has("python")
