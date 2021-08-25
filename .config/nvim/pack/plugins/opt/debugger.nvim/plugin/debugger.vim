" https://sourceware.org/gdb/onlinedocs/gdb/Command-and-Variable-Index.html

if get(g:, 'loaded_debugger', 0)
  finish
endif
let g:loaded_debugger = 1

let s:command_token = strftime('%s') * 1299827
let s:Namespace = nvim_create_namespace('debugger.nvim')

function s:ParseAny(input) abort
  try
    return s:ParseString(a:input)
  catch
  endtry

  try
    return s:ParseList(a:input)
  catch
  endtry

  try
    return s:ParseObject(a:input)
  endtry

  throw 'cannot parse: ' . a:input
endfunction

function s:ParseString(input) abort
  let input = a:input
  let [_, ret, input; _] = matchlist(input, '\v^"(%([^"\\]*|\\.)*)"(.*)')
  " unescape()
  let ret = substitute(ret, '\v\\(.)', {m->get({'n': "\n", 't': "\t"}, m[1], m[1])}, 'g')
  " let ret = substitute(ret, '\v\\(U[0-9a-zA-Z]{4}|u[0-9a-zA-Z]{4}|x[0-9a-zA-Z]{2}|.)', {m-> m.'x'}, '')
  return [ret, input]
endfunction

function s:ParseList(input) abort
  let input = a:input
  let ret = []
  let [_, input; _] = matchlist(input, '\v^\[(.*)')
  while 1
    try
      let [_, input; _] = matchlist(input, '\v^\](.*)')
      break
    catch
      if !empty(ret)
        let [_, input; _] = matchlist(input, '\v^,(.*)')
      endif
    endtry
    " Braindead list: [frame={},frame={},frame={}].
    " Ignore key from the key-value pair.
    let [_, input; _] = matchlist(input, '\v^%([a-z\-_]*\=)?(.*)')

    let [elem, input] = s:ParseAny(input)
    call add(ret, elem)
  endwhile
  return [ret, input]
endfunction

function s:ParseObject(input) abort
  let input = a:input
  let ret = {}
  try
    let [_, input; _] = matchlist(input, '\v^\{(.*)')
    let end = '\v^\}(.*)'
  catch
    let end = '\v^%(\\n)?$(.*)'
  endtry

  while 1
    try
      let [_, input; _] = matchlist(input, end)
      break
    catch
      if !empty(ret)
        let [_, input; _] = matchlist(input, '\v^,(.*)')
      endif
    endtry
    let [_, key, input; _] = matchlist(input, '\v^([a-z\-_]*)\=(.*)')
    let [value, input] = s:ParseAny(input)
    let ret[key] = value
  endwhile

  return [ret, input]
endfunction

function s:ParseData(input, action) abort
  let input = a:input
  if a:action
    try
      let [_, name; _] = matchlist(input, '\v^([a-z\-]*)$')
      return [name, {}]
    catch
      let [_, name, input; _] = matchlist(input, '\v^([a-z\-]*),(.*)')
    endtry
  endif
  let r = s:ParseAny(input)
  let [data, input] = r
  if !empty(input)
    throw 'parse error: ' . input
  endif
  return a:action ? [name, data] : data
endfunction

function s:UpdatePanels() abort
  for win in range(1, winnr('$'))
    let buf = winbufnr(win)
    let bufname = bufname(buf)
    let name = matchstr(bufname, '\m^debugger://\zs.*')
    if empty(name)
      continue
    endif

    try
      call s:UpdatePanel(buf, name)
    finally
      call setbufvar(buf, '&modified', 0)
    endtry
  endfor

    " call s:SendCommand('-data-list-register-values r', function('s:on_registers_info'))
    " call s:SendCommand('-data-list-changed-registers'.s:thread_frame(), function('s:on_list_changed_registers', [s:Program.current_thread]))

  " Annotations does not get updated otherwise.
  redraw!
endfunction

function s:GoFrame(rel)
  let thread = s:Program.threads[s:Program.current_thread]
  let thread.current_frame += a:rel
  let thread.current_frame = max([min([get(thread, 'current_frame', 0), len(thread.stack) - 1]), 0])

  call s:UpdatePC()
endfunction

function s:UpdatePC() abort
  let thread = s:Program.threads[s:Program.current_thread]
  if has_key(thread, 'stack')
    let current = thread.stack[thread.current_frame]

    " Remove previous mark.
    for id in range(1000, 1050)
      call sign_unplace('debugger', { 'id': id })
    endfor

    for frame in thread.stack
      echom 'frame '.string(frame)
      if has_key(frame, 'line')
        let buf = bufnr(get(frame, 'fullname', frame.file), frame.level ==# current.level)
        echom 'ok '.string(frame).buf
        let win = bufwinnr(buf)
        if frame.level ==# current.level
          if win !=# -1
            silent! execute win 'windo normal'
          else
            if bufname() =~# '\m^debugger://'
              split
            endif
            execute 'buffer' buf
          endif
        else
          if win ==# -1
            continue
          endif
        endif

        call s:GenerateFrameDecorators(frame.level)
        call sign_place(frame.level ==# current.level ? 1000 : 1001 + frame.level, 'debugger', 'Debugger'.(frame.level ==# current.level ? 'Current' : '').'Frame'.frame.level, buf, {
        \  'lnum': frame.line,
        \  'priority': 99
        \})

        " Scroll into view and make sure current level is focused.
        if frame.level ==# current.level || frame.file !=# current.file
          execute 'normal!' frame.line.'G'
        endif

        call s:SendCommand(printf('-symbol-info-functions --name %s', frame.func), function('s:ShowFrameArgs', [frame]))
      endif
    endfor

  endif
endfunction

function s:StringifyStoppedThread(data)
  return printf('thread %d (core %s); thread %s stopped', a:data['thread-id'], a:data.core, a:data['stopped-threads'])
endfunction

function s:HandleGDBOutput(job_id, data, event) dict abort
  let self.lines[-1] .= a:data[0]
  call extend(self.lines, a:data[1:])
  for line in self.lines[:-2]
    let [line, token, prefix, data; _] = matchlist(line, '\v(\d*)(.)([^\r]*)')
    " echom line
    if prefix ==# '^'
      try
        let [DoneCb, ErrorCb] = s:Callbacks[token]
      catch
        " Maybe another interpreter is running and that's why we do not found
        " the token.
        continue
      endtry
      unlet s:Callbacks[token]
      try
        let result = s:ParseData(data, 1)
      catch //
        echoe a:data
        throw v:exception
      endtry

      if result[0] ==# 'done' || result[0] ==# 'running'
        call DoneCb(result[1])

      elseif result[0] ==# 'exit'
        " Ignore
      elseif result[0] ==# 'error'
        if !ErrorCb()
          echohl DebuggerError|echom printf('debugger.nvim: gdb: %s', result[1].msg)|echohl None
        endif
      else
        echohl DebuggerError|echom printf('debugger.nvim: Unknown response: %s.', string(result))|echohl None
      endif

    elseif prefix ==# '+'
      " echom  '+: ' . line[1:]

    elseif prefix ==# '*'
      let [action, data] = s:ParseData(data, 1)
      " echom  '*: ' . string([action, data])
      "
      if action ==# 'stopped'
        call s:SendCommand('-thread-info', function('s:HandleGDBThreadInfo', [0]))

        " Append message history and update status line. We save and show
        " slightly different messages.
        let data.core = get(data, 'core', '?')

        let message = ''
        if has_key(data, 'reason')
          if data.reason ==# 'breakpoint-hit'
            let action = printf('Breakpoint hit')
            let message = 'by '.s:StringifyStoppedThread(data)
          elseif data.reason ==# 'function-finished'
            let action = printf('Function exited')
            let message = 'on '.s:StringifyStoppedThread(data)

            let thread = s:Program.threads[data['thread-id']]
            " We were inside stack[0]. When function finishes we will be at
            " stack[1]. It contains the previous state of the stack so it will
            " exactly give us where stack[0] has been called.
            let frame = thread.stack[1]
            let buf = bufnr(frame.fullname, 1)
            call nvim_buf_set_virtual_text(buf, s:Namespace, str2nr(frame.line) - 1, [
            \  s:vthead, ['return', 'Keyword'], [' '], [get(data, 'return-value', 'void'), 'Normal'], s:vttail
            \], {})

          elseif data.reason ==# 'end-stepping-range' " -exec-step
            let action = 'Stepped'
            let message = 'on '.s:StringifyStoppedThread(data)

          elseif data.reason ==# 'location-reached' " -exec-until
            let action = 'Location reached'
            let message = 'by '.s:StringifyStoppedThread(data)

          elseif data.reason ==# 'stop' " -exec-stop
            let action = printf('At %s in %s', data['addr'], data['source'])

          elseif data.reason ==# 'watchpoint-trigger' " -break-watch
            let action = printf('Watchpoint %s', data.exp)
            let message = printf('old=%s; new=%s', data.value.old, data.value.new)

          elseif data.reason ==# 'watchpoint-scope' " -break-watch
             " Ignore
            continue

          elseif data.reason ==# 'signal-received'
            let action = printf('Received %s, %s', data['signal-name'], data['signal-meaning'])
            let message = printf('on %s', s:StringifyStoppedThread(data))

          elseif data.reason ==# 'exited-normally'
            let action = 'Program terminated'
          elseif data.reason ==# 'exited'
            let action = 'Program terminated with exit status '.data['exit-code']
          elseif data.reason ==# 'exited-signalled'
            let action = 'Program terminated with signal '.data['signal-name'].', '.data['signal-meaning']
          else
            let action = string(data)
          endif
        elseif has_key(data, 'frame')
          let action = s:StringifyFrame(data.frame)
        endif

        if has_key(data, 'frame')
          " This one goes to message history.
          echom printf('%s(%s): %s %s', data.frame.func, data.frame.addr, action, message)
        else
          echom printf('%s %s', action, message)
        endif

        " And this one is displayed for the user.
        echohl DebuggerProgramStop
        echo 'STOPPED'
        echohl DebuggerStatusHighlight
        echon ' '.action.' '
        echohl None
        echon message

      elseif action ==# 'running'
        let thread_id = data['thread-id'] ==# 'all' ? 0 : data['thread-id']
        for thread in values(get(s:Program, 'threads', []))
          if !thread_id || thread_id ==# theard.id
            let thread.state = 'running'
          endif
        endfor
        for id in range(1000, 1050)
          call sign_unplace('debugger', { 'id': id })
        endfor
        echohl DebuggerProgramStart|echon 'RUNNING'|echohl None
      endif
    elseif prefix ==# '='
      " echom line string(s:ParseData(data, 1))
      let [option, data] = s:ParseData(data, 1)
      if option ==# 'breakpoint-created' || option ==# 'breakpoint-modified'
        call call('s:BreakUpdate', [], data.bkpt)
      elseif option ==# 'breakpoint-deleted'
        call s:HandleBreakDelete(data.id)
      else
        " echom  '=: ' . option ' = ' string(data)
      endif

    elseif prefix ==# '~'
      let buf = bufnr('debugger://output', 0)
      if buf !=# -1
        call append('$', string(s:ParseData(data, 0)))
      endif
    elseif prefix ==# '@'

    elseif prefix ==# '&'
      echohl DebuggerError
      echom 'debugger.nvim: gdb: '.s:ParseData(data, 0)
      echohl None

    elseif prefix ==# "(" && data ==# 'gdb) '
    else
      " Drop line.
    endif
  endfor
  let self.lines = self.lines[-1:]
endfunction

" call s:SendCommand(printf('save breakpoints %s', fnameescape('.gdb_breakpoints')))

function s:BreakUpdate() dict
  let self.line = str2nr(self.line)
  let s:Program.breakpoints[self.number] = self
  call call('s:PlaceBreakpoint', [], self)
endfunction

function s:HandleBreakDelete(breakpoint_id) abort
  try
    call call('s:UnplaceBreakpoint', [], s:Program.breakpoints[a:breakpoint_id])
    unlet s:Program.breakpoints[a:breakpoint_id]
  catch
  endtry
endfunction

function s:HandleBreakInsert(data) abort
  call call('s:BreakUpdate', [], a:data.bkpt)
endfunction

function s:HandleGDBBreakpointTable(data) abort
  for breakpoint in a:data['BreakpointTable'].body
    call call('s:BreakUpdate', [], breakpoint)
  endfor
endfunction

function s:HandleBreakUpdate(breakpoint_id, ...)
  call s:SendCommand('-break-info '.a:breakpoint_id, function('s:HandleGDBBreakpointTable'))
endfunction

function! DebuggerDebugging()
  return has_key(s:, 'job')
endfunction

function s:HandleDebuggerExit(job_id, data, evenet)
  unlet! s:job

  call s:map_restore()
  doautocmd User DebuggerLeave

  augroup DebuggerBreakpoints
    autocmd!
  augroup END
endfunction

augroup DebuggerDefaults
  autocmd!
  autocmd User DebuggerEnter call <SID>map_default()
augroup END

function s:map_restore() abort
  for keymap in s:saved_keymaps.n
    call nvim_set_keymap('n', keymap.lhs, keymap.rhs, { 'script': keymap.script ? v:true : v:false, 'expr': keymap.expr ? v:true : v:false, 'noremap': keymap.noremap ? v:true : v:false, 'nowait': keymap.nowait ? v:true : v:false, 'silent': keymap.silent ? v:true : v:false })
  endfor

  unlet s:saved_keymaps
endfunction
 
let s:regnames = []
let s:regnamescn = -1
let s:regpos = {}

function s:get_panel(name) abort
  let buf = bufnr('debugger://'.a:name)
  return bufwinnr(buf) !=# -1 ? buf : 0
endfunction

function s:on_stack_list_frames(thread_id, data) abort
  let thread = s:Program.threads[a:thread_id]
  let thread.stack = a:data.stack
  let thread.current_frame = min([thread.current_frame, len(get(thread, 'stack', [])) - 1])

  if s:Program.current_thread ==# a:thread_id
    call s:UpdatePC()
  endif

  call s:UpdatePanels()
endfunction

function s:on_stack_list_arguments(thread_id, data) abort
  let thread = s:Program.threads[a:thread_id]
  let stack_args = a:data['stack-args']
  if len(stack_args) !=# len(thread.stack)
    " Out-of-sync and there is no way to make it right since we do not know
    " what mostthe bottom (highest number) stack index at the moment
    " stack-list-arguments was queried.
    return
  endif
  for args in stack_args
    let thread.stack[args.level].args = args.args
  endfor

  call s:UpdatePanels()
endfunction

function s:on_stack_list_variables(thread_id, frame_id, data) abort
  let thread = s:Program.threads[a:thread_id]
  let frame = thread.stack[a:frame_id]
  let frame.variables = a:data.variables

  call s:UpdatePanels()
endfunction

function s:on_list_register_values(data)
  let thread = s:Program.threads[s:Program.current_thread]
  echoe 'eu'
  let thread.regs = a:data
endfunction

function s:HandleGDBThreadInfo(thread_id, data) abort
  " a:thread_id := 0 => list all threads
  if !a:thread_id
    for thread in values(s:Program.threads)
      let thread.delete = 1
    endfor
  endif

  for thread in a:data.threads
    let program_thread = get(get(s:Program, 'threads', {}), thread.id, {})
    let thread.current_frame = get(program_thread, 'current_frame', 0)
    " if !has_key(a:data, 'id')
      call s:SendCommand('-stack-list-frames --thread '.thread.id, function('s:on_stack_list_frames', [thread.id]))
      call s:SendCommand('-stack-list-arguments --thread '.thread.id.' 2', function('s:on_stack_list_arguments', [thread.id]))
    " endif

    call s:SendCommand('-stack-list-variables --thread '.thread.id.' --frame 0 2', function('s:on_stack_list_variables', [thread.id, 0]))
    if has_key(program_thread, 'stack')
      let thread.stack = program_thread.stack
    endif
    " let a:data.stack[a:data.frame.level] = a:data.frame
    " unlet a:data.frame
    let s:Program.threads[thread.id] = thread
  endfor

  if !a:thread_id
    for [thread_id, thread] in items(s:Program.threads)
      if get(thread, 'delete', 0) ==# 1
        if s:Program.current_thread ==# thread_id
          unlet! s:Program.current_thread
        endif
        unlet! s:Program.threads[thread_id]
      endif
    endfor
  endif

  if has_key(a:data, 'current-thread-id')
    let s:Program.current_thread = a:data['current-thread-id']
  endif

  if !has_key(s:Program, 'current_thread') && !empty(s:Program.threads)
    let thread = values(s:Program.threads)[0]
    let s:Program.current_thread = thread.id
    call s:UpdatePC()
  endif

  call s:UpdatePanels()
endfunction

function s:on_list_changed_registers(thread_id, result) abort
  call s:SendCommand('-data-list-register-values --thread '.thread_id.' --skip-unavailable x '.join(a:result['changed-registers'], ' '), function('s:on_list_register_values'))
endfunction

highlight default link DebuggerRegisterChange DiffChange
highlight link DebuggerError Error
highlight default DebuggerStatusHighlight gui=bold
highlight default DebuggerProgramStart gui=bold guibg=#a0df2f guifg=#fefefe
highlight default DebuggerProgramStop gui=bold guibg=#f40000 guifg=#fefefe
highlight default DebuggerProgramConnect guibg=#fde74c guifg=#000000

function s:aeu(result)
  let buf = s:get_panel('registers')
  if !buf
    return
  endif

  let cbuf = bufnr()
  try
    let addnew = nvim_buf_get_lines(buf, -2, -1, 0)[0] !=# '.'
  catch
    let addnew = 1
  endtry

  try
    call nvim_buf_clear_namespace(buf, s:Namespace, 0, -1)

    let view = winsaveview()

    let cn = changenr()

    for reg in a:result['register-values']
      let reg.name = s:regnames[reg.number]
      let [lnum, col, len] = get(s:regpos, reg.number, [0, 0, 0])
      if cn ==# s:regnamescn && lnum ># 0
        let valcol = col
        let text = reg.value
        let newlen = len(text)
        let text = text.repeat(' ', len - newlen)
        let s:regpos[reg.number][2] = newlen
        let new = 0
        let len = newlen
      else
        let [lnum, col] = searchpos('\V\<'.reg.name.'=\zs')
        if lnum ==# 0
          if !addnew
            continue
          endif
          let lnum = line('$')
          let col = 1
          let new = 1
          let valcol = col + len(reg.name)
          let text = reg.name.'='.reg.value
          let len = len(reg.value)
        else
          let valcol = col
          let text = reg.value
          let newlen = len(text)
          let text = text.repeat(' ', len - newlen)
          let s:regpos[reg.number][2] = newlen
          let new = 0
          let len = newlen
        endif
        let lnum -= 1
        let s:regpos[reg.number] = [lnum, valcol, len]
      endif
      try
        let line = nvim_buf_get_lines(buf, lnum, lnum + 1, 1)[0]
      catch
        let line = ''
      endtry
      call nvim_buf_set_lines(buf, lnum, lnum + 1, 0, [matchstr(strpart(line, 0, col - 1).text.strpart(line, col - 1 + len(text)), '\v^.{-}\ze\s*$')] + (new ? [''] : []))

      call nvim_buf_add_highlight(buf, s:Namespace, 'DebuggerRegisterChange', lnum, valcol, valcol + len)
    endfor
    let s:regnamescn = cn

    call winrestview(view)
  finally
    silent! execute bufwinnr(cbuf) 'windo normal'
    call s:finish_pane_update(buf)
  endtry
endfunction

function s:StringifyValue(value) abort
  if a:value =~# '0x0$'
    return 'NULL'
  endif
  return a:value
endfunction

function s:StringifyFrameArguments(frame) abort
  return join(map(copy(get(a:frame, 'args', [])), {_, arg-> printf('%s=%s', arg.name, s:StringifyValue(arg.value))}), ', ')
endfunction

function s:StringifyFrame(frame) abort
  return printf('%s in %s (%s) ', a:frame.addr, a:frame.func, s:StringifyFrameArguments(a:frame)).(has_key(a:frame, 'line')
  \  ? printf('at %s:%d', a:frame.file, a:frame.line)
  \  : printf('from %s', get(a:frame, 'from', '???'))
  \)
endfunction

function s:ViewBreakpoints(...) abort
  let list = []
  let fullname = DebuggerFilename()
  let buf = bufnr()
  for breakpoint in sort(values(s:Program.breakpoints))
    if breakpoint.fullname ==# fullname
      call add(list, { 'bufnr': buf, 'lnum': breakpoint.line, 'text': printf('%s times=%d', (breakpoint.enabled ==# 'y' ? 'B' : 'b'), breakpoint.times) })
    endif
  endfor
  call setloclist(bufwinnr(buf), list)
endfunction

function s:UpdatePanel(buf, name) abort
  let lines = []
  for thread in sort(values(s:Program.threads), {x,y-> x.id - y.id})
    call add(lines, printf('%s %d %s %s:', thread.id == s:Program.current_thread ? '*' : ' ', thread.id, thread['target-id'], thread.state))
    for frame in get(thread, 'stack', [])
      call add(lines, printf('  #%-2d %s', frame.level, s:StringifyFrame(frame)))
      for var in get(frame, 'variables', [])
        if !get(var, 'arg', 0)
          call add(lines, printf('    %s=(%s)%s', var.name, var.type, s:StringifyValue(get(var, 'value', 'void'))))
        endif
      endfor
    endfor
    call add(lines, '')
  endfor
  call nvim_buf_set_lines(a:buf, 0, -1, 0, lines)
endfunction

function s:ShowFrameArgs(frame, data) abort
  let buffer = s:GetBuffer(a:frame.fullname)
  if buffer ==# -1
    return
  endif

  for file in get(a:data.symbols, 'debug', [])
    if file.fullname !=# a:frame.fullname
      continue
    endif

    let symbol = file.symbols[0]

    call nvim_buf_set_virtual_text(buffer, s:Namespace, str2nr(symbol.line) - 1, [
    \  s:vthead, [s:StringifyFrameArguments(a:frame), 'Normal'], s:vttail
    \], {})
    break
  endfor
endfunction

function s:StartDebugger(master) abort
  if has_key(s:, 'job')
    return
  endif

  if a:master
    " We start GDB and DebuggerConsole can be used to open up GDB somewhere
    " else.
    let cmdline = ['gdb', '--interpreter=mi3', '-quiet', '-fullname', '-nh']
  else
    " GDB is already started and "new-ui" can be used to spin-up ourself.
    let cmdline = ['sleep', 'infinity']
  endif

  let s:job = jobstart(cmdline, {
  \  'on_stdout': function('s:HandleGDBOutput'),
  \  'on_stderr': function('s:HandleGDBOutput'),
  \  'on_exit': function('s:HandleDebuggerExit'),
  \  'lines': [''],
  \  'pty': v:true,
  \})

  augroup DebuggerBreakpoints
    autocmd!
    autocmd BufEnter * :call <SID>setup_breakpoints()
  augroup END

  let s:saved_keymaps = { 'n': nvim_get_keymap('n') }
  doautocmd User DebuggerEnter

  let s:Program = {'threads': {}, 'breakpoints': {}}
  let s:Callbacks = {}
  " We are async.
  call s:SendCommand('-gdb-set mi-async on')
  " Enable Python-base frame filters.
  call s:SendCommand('-enable-frame-filters')
  " call s:SendCommand(\"define hook-stop\nframe\nbacktrace\nend\")
  " hook[post]-(run|continue|{command-name})
  call s:SendCommand('-break-list', function('s:HandleGDBBreakpointTable'))

  call s:SendCommand('-thread-info', function('s:HandleGDBThreadInfo', [0]))
endfunction

let s:vthead = [' /* ', 'Comment']
let s:vttail = [' */ ', 'Comment']

function s:SendCommand(cmd, ...) abort
  if !exists('s:job')
    echohl DebuggerError
    echon 'debugger.nvim: Debugger process is not started'
    echohl None
    return
  endif

  let s:command_token += 1
  let s:Callbacks[s:command_token] = [get(a:000, 0, function('s:HandleDoneDefault')), get(a:000, 1, function('s:HandleErrorDefault'))]
  let msg = s:command_token.a:cmd."\n"
  " echom '->' . msg
  call chansend(s:job, msg)
endfunction

function s:PlaceBreakpoint() dict abort
  let buf = bufnr(self.fullname)
  if buf ==# -1
    return
  endif

  call call('s:UnplaceBreakpoint', [], self)
  let space = [' ', 'Normal']
  let self.debugger_sign = sign_place(0, 'debugger', 'DebuggerBreakpoint'.(self.enabled ==# 'y' ? '' : 'Disabled'), buf, { 'lnum': str2nr(self.line), 'priority': 89 })
  let self.debugger_signns = nvim_buf_set_virtual_text(buf, s:Namespace, self.line - 1,
  \  [s:vthead]
  \  + (has_key(self, 'thread') ? [[' thread='.self.thread, 'Normal'], space] : [])
  \  + (0 <# get(self, 'ignore', 0) ? [['ignore=', 'Normal'], [self.ignore, 'Number'], space] : [])
  \  + [['times=', 'Normal'], [self.times, 'Number']]
  \  + (has_key(self, 'cond') ? [space, ['if', 'Conditional'], space] + s:GetHighlights(&filetype, 0, self.cond) : [])
  \  + [s:vttail]
  \, {})
endfunction

function s:UnplaceBreakpoint() dict abort
  if has_key(self, 'debugger_sign')
    call sign_unplace('debugger', { 'id': self.debugger_sign })
    unlet self.debugger_sign
  endif
endfunction

function s:setup_breakpoints() abort
  let path = DebuggerFilename()
  for [_, breakpoint] in items(s:Program.breakpoints)
    if breakpoint.fullname ==# path
      call call('s:PlaceBreakpoint', [], breakpoint)
    endif
  endfor
endfunction

highlight default DebuggerBreakpoint      cterm=NONE guibg=#ee3000 guifg=#fcfcfc gui=bold ctermfg=160
highlight link DebuggerBreakpointDisabled DebuggerBreakpoint
call sign_define('DebuggerBreakpoint', {
\  'text': 'B>',
\  'texthl': 'DebuggerBreakpoint',
\})
call sign_define('DebuggerBreakpointDisabled', {
\  'text': 'b>',
\  'texthl': 'DebuggerBreakpointDisabled',
\})
call sign_define('DebuggerHardwareBreakpoint', {
\  'text': 'H>',
\  'texthl': 'DebuggerHardwareBreakpoint',
\})
call sign_define('DebuggerHardwareBreakpointDisabled', {
\  'text': 'h>',
\  'texthl': 'DebuggerHardwareBreakpointDisabled',
\})

function s:GenerateFrameDecorators(depth)
  if !empty(sign_getdefined('DebuggerCurrentFrame'.a:depth))
    return
  endif

  if a:depth ==# 0
    highlight DebuggerFrame0 gui=NONE guibg=#cfcfcf
    highlight DebuggerCurrentFrame0 gui=NONE guibg=#fcfc00
  else
    execute printf('highlight link DebuggerFrame%d DebuggerFrame%d', a:depth, a:depth - 1)
    execute printf('highlight link DebuggerCurrentFrame%d DebuggerCurrentFrame%d', a:depth, a:depth - 1)
  endif

  execute printf('highlight link DebuggerFrameSign%d DebuggerFrame%d', a:depth, a:depth)
  call sign_define('DebuggerFrame'.a:depth, {
  \  'text': (a:depth.'>')[:1],
  \  'texthl': 'DebuggerFrameSign'.a:depth,
  \  'linehl': 'DebuggerFrame'.a:depth,
  \  'numhl': 'DebuggerFrame'.a:depth
  \})

  execute printf('highlight link DebuggerCurrentFrameSign%d DebuggerCurrentFrame%d', a:depth, a:depth)
  call sign_define('DebuggerCurrentFrame'.a:depth, {
  \  'text': (a:depth.'>')[:1],
  \  'texthl': 'DebuggerCurrentFrameSign'.a:depth,
  \  'linehl': 'DebuggerCurrentFrame'.a:depth,
  \  'numhl': 'DebuggerCurrentFrame'.a:depth
  \})
endfunction

function s:HandleDoneDefault(data) abort
endfunction

function s:HandleErrorDefault() abort
endfunction

function s:OnDebuggerConnected(data) abort
  " call s:SendCommand(printf('source %s', fnameescape('/tmp/bkpts')), function('s:startup'))
  " call s:SendCommand('-data-list-register-names', function('s:list_reg_names_cb'))
  " call feedkeys(\"B main\<CR>\", \"tm\");
endfunction

function s:list_reg_names_cb(result)
  let s:regnames = a:result['register-names']

  let regsbuf = bufnr('debugger://registers', 1)
  execute 'vsplit | buffer' regsbuf ' | resize 6'
endfunction

autocmd BufWinEnter debugger://* ++nested
  \ setlocal buftype=nofile bufhidden=wipe noswapfile undolevels=-1 nonumber norelativenumber nolist|
  \ let &l:filetype = substitute(expand("<amatch>"), '\V://', '-', '')|
  \ let b:did_filetype = 1|
  \ call s:UpdatePanels()

function s:BufReadRemote() abort
  echom 'read'
  call setbufvar(a:buffer, '&buftype', 'nofile')
  call setbufvar(a:buffer, '&swapfile', 0)
  call setbufvar(a:buffer, '&modifiable', 0)

  let tmpfile = tempname()
  call s:SendCommand(printf('-target-file-get %s %s', matchstr(bufname(a:buf), '\m://\zs.*'), tmpfile), function('soHandleGDBTargetFileGet', [a:buf, tmpfile]))
endfunction

function s:HandleGDBTargetFileGet(buf, tmpfile, result) abort
  " execute printf('normal %dbufdo :0read %s', a:buf, fnameescape(a:tmpfile))
  call setbufvar(a:buf, '&buftype', 'acwrite')
  " call nvim_buf_set_lines(a:buf, 0, -1, 1, readfile(a:tmpfile))
  call setbufvar(a:buf, '&modified', 0)
  call delete(a:tmpfile)
endfunction

function s:BufWriteRemote() abort
  " Make file unmodifiable so user cannot modify while saving.
  call setbufvar(a:buf, '&modifiable', 0)
  call s:SendCommand(printf('-target-file-put %s %s', expand('<afile>:p'), DebuggerFilename().'.gdb', function('s:HandleGDBTargetFilePut', [a:buf])))
endfunction

function s:HandleGDBTargetFilePut(buf, tmpfile, result) abort
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufvar(a:buf, '&modified', 0)
endfunction

augroup DebuggerRemote
  autocmd!
  autocmd BufRead debugger-target://* call <SID>BufReadRemote()
  autocmd BufWriteCmd debugger-target://* call <SID>BufWriteRemote()
augroup END

function s:startup(result)
  " call s:SendCommand(printf('source %s', fnameescape('.gdb_breakpoints')), function('s:startup'))
endfunction

function s:show_pwd_cb(result) abort
  redraw
  echo a:result.cwd
endfunction

" Get filename associated with buffer.
function s:GetBuffer(fname) abort
  return bufnr(a:fname)
endfunction

function DebuggerFilename() abort
  return matchstr(expand('%:p'), '\m^\%(debugger-target://\)\?\zs.*')
endfunction

" command! -range -nargs=? -count=1 DebuggerBreakpointDisable call <SID>SendCommand(empty(<q-args>) ? printf('-break-insert %s:%d', DebuggerFilename(), line('.')) : printf('-break-insert %s', <q-args>), function('<SID>HandleBreakInsert'))
" command! -range -nargs=+ -count=1 DebuggerBreakpointAddIf call <SID>SendCommand(printf('-break-insert %s:%d -c %s', DebuggerFilename(), line('.'), <q-args>), function('<SID>HandleBreakInsert'))
" command! -range DebuggerJump call <SID>SendCommand('-exec-jump <count>')
" command! DebuggerPwd call <SID>SendCommand('-environment-pwd', function('<SID>show_pwd_cb'))
" command! -nargs=+ DebuggerCd call <SID>SendCommand('-environment-cd <args>')

function g:DebuggerDebug() abort
  return s:Program
endfunction

function g:DebuggerBreakpoint(...) abort
  let fullname = DebuggerFilename()
  let line = line('.')
  for breakpoint in values(s:Program.breakpoints)
    if breakpoint.line ==# line && breakpoint.fullname ==# fullname
      return breakpoint
    endif
  endfor
  return {}
endfunction

let s:hibuf = nvim_create_buf(v:false, v:true)
call setbufvar(s:hibuf, '&buflisted', 1)
call setbufvar(s:hibuf, '&buftype', 'nofile')
call setbufvar(s:hibuf, '&swapfile', 0)
call setbufvar(s:hibuf, '&bufhidden', 'hide')
call setbufvar(s:hibuf, '&undolevels', -1)

function s:GetHighlights(filetype, ranges, text)
  let list = []

  let w = nvim_get_current_win()
  let hiwin = nvim_open_win(s:hibuf, v:true, {'relative': 'editor', 'width': 20, 'height': 1, 'row': 0, 'col': 0})

  if getbufvar(s:hibuf, '&filetype') !=# a:filetype
    call setbufvar(s:hibuf, '&filetype', a:filetype)
  endif

  call nvim_buf_set_lines(s:hibuf, 0, -1, 0, [a:text])
  for i in range(1, len(a:text))
    let group = synIDattr(synID(1, i, 1), 'name')

    if a:ranges
      call add(list, [i - 1, i, group])
    else
      call add(list, [a:text[i - 1], group])
    endif
  endfor

  call nvim_win_close(hiwin, v:true)
  call nvim_set_current_win(w)

  return list
endfunction

function g:DebuggerGDBInitComplete(prefix) abort
  let s:fake_completion_for = a:prefix
endfunction

let s:completion_for = ''

function s:HandleGDBComplete(prefix, data) abort
  if s:completion_for ==# a:prefix
    let s:completions = map(a:data.matches, {_,match-> matchstr(match, '\v[^ ]+$')})
    " Auto-fire completion. First, change the buffer, then tab.
    call feedkeys(" \<Backspace>\<Tab>", 'tn')
  endif
endfunction

let s:completions = []
function g:DebuggerGDBComplete(head, cmdline, pos) abort
  if s:completion_for !=# s:fake_completion_for.a:head
    let s:completion_for = s:fake_completion_for.a:head
    let s:completions = []
    call s:SendCommand('-complete "'.escape(s:completion_for, '"').'"', function('s:HandleGDBComplete', [s:completion_for]))
  endif
  return s:completions
endfunction

function s:SetBreakInfo(command, prompt, prop, completion, ...) abort
  if a:0 ==# 0
    let breakpoint = DebuggerBreakpoint()

    call g:DebuggerGDBInitComplete(a:completion)
    let text = input({
    \  'prompt': a:prompt,
    \  'default': get(breakpoint, a:prop, ''),
    \  'completion': 'customlist,DebuggerGDBComplete',
    \  'cancelreturn': get(breakpoint, a:prop, ''),
    \  'highlight': function('s:GetHighlights', [&filetype, 1])
    \})
    call g:DebuggerGDBInitComplete('')

    if empty(breakpoint)
      if a:0 ==# 0
        call s:SendCommand(printf('-break-insert %s:%d', DebuggerFilename(), line('.')), function('s:SetBreakInfo', [a:command, a:prompt, a:prop, a:completion, text]))
      endif
      return
    endif
  else
    let text = a:1
    let breakpoint = a:2.bkpt
    call s:HandleBreakInsert(a:2)
  endif

  let Cb = function('s:HandleBreakUpdate', [breakpoint.number])
  call s:SendCommand(printf('%s %d %s', a:command, breakpoint.number, text), Cb, Cb)
endfunction

function s:map_default()
  nnoremap <silent> x :call <SID>UpdatePanels()<CR>
  nnoremap <silent> ot :15split debugger://threads<CR>
  nnoremap <silent> ob :call <SID>ViewBreakpoints()<bar>lwindow<CR>

  nnoremap <silent> bb :if empty(DebuggerBreakpoint())<bar>call <SID>SendCommand(printf('-break-insert %s:%d', DebuggerFilename(), line('.')), function('<SID>HandleBreakInsert'))<bar>endif<CR>
  nnoremap <silent> bI :call <SID>SetBreakInfo('-break-after', 'break ignore=', 'ignore', 'ignore 0 ')<CR>
  nnoremap <silent> bi :call <SID>SetBreakInfo('-break-condition', 'break if ', 'cond', 'break 0 if ')<CR>
  nnoremap B :call g:DebuggerGDBInitComplete('break ')<bar>call <SID>SendCommand('-break-insert '.substitute(input({ 'prompt': 'break ', 'completion': 'customlist,DebuggerGDBComplete' }), '%', DebuggerFilename().':', ''), function('<SID>HandleBreakInsert'))<CR>
  nmap <silent> * bb
  nnoremap <silent> db :call <SID>SendCommand('-break-delete '.(DebuggerBreakpoint().number), function('<SID>HandleBreakDelete', [DebuggerBreakpoint().number]))<CR>
  nnoremap <silent> ]b " prev by line
  nnoremap <silent> [b " prev by line
  nnoremap <silent> ]B " prev by id
  nnoremap <silent> [B " prev by id
  nnoremap <silent> p :call <SID>SendCommand('-exec-interrupt')<CR>
  nnoremap <silent> P :call <SID>SendCommand('-exec-interrupt --all')<CR>
  nnoremap A :DebuggerRunArguments<space>
  nnoremap <silent> r :call <SID>SendCommand('-exec-run')<CR>
  nnoremap <silent> R :call <SID>SendCommand('-exec-run --start')<CR>
  nnoremap <silent> c :call <SID>SendCommand('-exec-continue')<CR>
  nnoremap <silent> C :DebuggerJump<CR>
  nnoremap <silent> J :call <SID>GoFrame(-1)<CR>
  nnoremap <silent> K :call <SID>GoFrame(1)<CR>
  nmap <silent> - J
  nmap <silent> + K
  nnoremap <silent> n :call <SID>SendCommand('-exec-next '.v:count1)<CR>
  nnoremap <silent> N :call <SID>SendCommand('-exec-next --reverse '.v:count1)<CR>
  nnoremap <silent> t :call <SID>SendCommand('-exec-step-instruction '.v:count1)<CR>
  nnoremap <silent> T :call <SID>SendCommand('-exec-step-instruction --reverse '.v:count1)<CR>
  nnoremap <silent> s :call <SID>SendCommand('-exec-step '.v:count1)<CR>
  nnoremap <silent> S :call <SID>SendCommand('-exec-step --reverse '.v:count1)<CR>
  nnoremap <silent> f :call <SID>SendCommand('-exec-finish')<CR>
  nnoremap <silent> F :call <SID>SendCommand('-exec-return')<CR>
  nnoremap <silent> u :call <SID>SendCommand('-exec-until')<CR>
  nnoremap <silent> U :call <SID>SendCommand(printf('-exec-until %s:%d', DebuggerFilename(), line('.')))<CR>
  nnoremap <C-c><C-c> DebuggerKill<CR>
endfunction


let s:address = 'remote 127.0.0.1:20001'

command! DebuggerStart call s:StartDebugger(1)
command! DebuggerUI call s:StartDebugger(0)|echom printf('debugger.nvim: use "new-ui mi3 %s" to connect', nvim_get_chan_info(s:job)['pty'])

" call s:SendCommand('set sysroot /')

command! -nargs=* DebuggerAttach call s:SendCommand(printf('-target-attach %s', <q-args>))
command! -nargs=* DebuggerDisconnect call s:SendCommand('-target-disconnect')
command! -nargs=* DebuggerQuit call s:SendCommand('-gdb-exit')
command! -nargs=1 DebuggerConsole call s:SendCommand('new-ui console '.<q-args>)
command! DebuggerKill call jobstop(s:job)

function s:ShowInferiorTTY(data)
  echom printf('tty=%s', get(a:data, 'inferior_tty_terminal', '?'))
endfunction

command! -nargs=? DebuggerTTY call call('s:SendCommand', empty(<q-args>) ? ['-inferior-tty-show', function('s:ShowInferiorTTY')] : ['-inferior-tty-set '.<q-args>])

function DebuggerSendCommand(...)
  call call('s:SendCommand', a:000)
endfunction
