" quickrun: runner/termext: Runs by vim terminal feature.
"           based on runner/terminal.
" Author : thinca <thinca+vim@gmail.com>
"          statiolake <statiolake@gmail.com>
" License: zlib License

let s:VT = g:quickrun#V.import('Vim.ViewTracer')

let s:is_win = g:quickrun#V.Prelude.is_windows()
let s:runner = {
\   'config': {
\     'opener': 'auto',
\     'vsplit_width': 80,
\     'into': 0,
\   },
\ }


function! s:runner.validate() abort
  if !has('terminal')
    throw 'Needs +terminal feature.'
  endif
  if !s:is_win && !executable('sh')
    throw 'Needs "sh" on other than MS Windows.'
  endif
endfunction

function! s:runner.init(session) abort
  let a:session.config.outputter = 'null'
endfunction

function! s:runner.run(commands, input, session) abort
  let command = join(a:commands, ' && ')
  if a:input !=# ''
    let inputfile = a:session.tempname()
    call writefile(split(a:input, "\n", 1), inputfile, 'b')
    let command = printf('(%s) < %s', command, inputfile)
  endif
  let cmd_arg = s:is_win ? printf('cmd.exe /c (%s)', command)
  \                      : ['sh', '-c', command]
  let options = {
  \   'term_name': 'quickrun: ' . command,
  \   'curwin': 1,
  \   'close_cb': self._job_close_cb,
  \   'exit_cb': self._job_exit_cb,
  \ }

  let self._key = a:session.continue()
  let prev_window = s:VT.trace_window()

  " If we can determine the previous buffer, use the buffer. If there are no
  " buffer or multiple buffers found, simply create a new buffer.
  let qrwinnr = bufwinnr(bufnr('quickrun'))
  if qrwinnr >= 0
    execute qrwinnr . 'wincmd w'
  else
    if self.config.opener !=# 'auto'
      let cmd = self.config.opener
    else
      let cmd = winwidth(0) >= self.config.vsplit_width ? 'vnew' : 'new'
    endif
    execute cmd
  endif
  let self._bufnr = term_start(cmd_arg, options)
  if !self.config.into
    call s:VT.jump(prev_window)
  endif
endfunction

function! s:runner.sweep() abort
  if has_key(self, '_bufnr') && bufexists(self._bufnr)
    let job = term_getjob(self._bufnr)
    while job_status(job) ==# 'run'
      call job_stop(job)
    endwhile
  endif
endfunction

function! s:runner._job_close_cb(channel) abort
  if has_key(self, '_job_exited')
    call quickrun#session(self._key, 'finish', self._job_exited)
  else
    let self._job_exited = 0
  endif
endfunction

function! s:runner._job_exit_cb(job, exit_status) abort
  if has_key(self, '_job_exited')
    call quickrun#session(self._key, 'finish', a:exit_status)
  else
    let self._job_exited = a:exit_status
  endif
endfunction

function! quickrun#runner#termext#new() abort
  return deepcopy(s:runner)
endfunction
