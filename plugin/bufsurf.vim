" bufsurf.vim
"
" MIT license applies, see LICENSE for licensing details.
if exists('g:loaded_bufsurf')
    finish
endif

let g:loaded_bufsurf = 1

command BufSurfBack :call <SID>BufSurfBack()
command BufSurfForward :call <SID>BufSurfForward()
command BufSurfList :call <SID>BufSurfList()

" disables history in the current window
" use this for for help windows, quickfix windows, etc
function s:DisableWindow()
  let w:window_history_disabled = 1
  unlet w:history
  unlet w:history_index
endfunction

function s:IsWindowDisabled()
  return exists('w:window_history_disabled')
endfunction

" check if the history reflects the current buffer
function s:CheckConsistency()
  if !exists('w:history')
    return
  endif

  let l:current_buf_nr = winbufnr(winnr())
  let l:hist_buf_nr = w:history[w:history_index]

  if l:hist_buf_nr != l:current_buf_nr
    let l:msg =
          \ "Warning: History index inconsistent: " .
          \ "Current buffer is b " . l:current_buf_nr .
          \ " '" . bufname(l:current_buf_nr) . "'. " .
          \ "History index on: b " . l:hist_buf_nr .
          \ " '" . bufname(l:hist_buf_nr) ."'"
    call s:BufSurfEcho(l:msg, 1)
  endif
endfunction

" Open the previous buffer in the navigation history for the current window.
function s:BufSurfBack()
  if s:IsWindowDisabled()
    return
  endif

  call s:CheckConsistency()

  if w:history_index == 0
    call s:BufSurfEcho("[<--", 0)
    return
  endif

  let w:history_index -= 1
  execute "b " . w:history[w:history_index]
endfunction

" Open the next buffer in the navigation history for the current window.
function s:BufSurfForward()
  if s:IsWindowDisabled()
    return
  endif

  call s:CheckConsistency()

  if w:history_index == len(w:history) - 1
    call s:BufSurfEcho("-->]", 0)
    return
  endif

  let w:history_index += 1
  execute "b " . w:history[w:history_index]
endfunction

function s:BufSurfPrintHistory()
  if !exists('w:history_index')
    return
  endif

  echomsg "[w" . winnr() . " b" . expand('<abuf>') . "] "
        \ . "history: (idx " . w:history_index . ") " . join(w:history, ";")
endfunction

" initialises history. The only entry is @bufnr
function s:InitHistoryAlone(bufnr)
  let w:history_index = 0
  let w:history = [a:bufnr]
endfunction

" initialises history. First entry is @bufnr. Next come all the other listed
" buffers
function s:InitHistoryAll(bufnr)
  call InitHistoryAlone(a:bufnr)

  for l:i in range(1, bufnr("$"))
    if buflisted(l:i + 0) && l:i != a:bufnr
      call add(w:history, l:i)
    endif
  endfor
endfunction

" Add the given buffer number to the navigation history for the window
" identified by winnr.
function s:BufSurfAppend(bufnr)
  if s:IsWindowDisabled()
    return
  endif

  " disable the window if the buffer is not a normal buffer
  " (e.g. if it is a help buffer)
  if !empty(&buftype)
    call s:DisableWindow()
    return
  endif

  if !exists('w:history_index')
    call s:InitHistoryAlone(a:bufnr)
    return
  endif

  " In case the newly added buffer is the same as the previously active
  " buffer, ignore it.
  if w:history[w:history_index] == a:bufnr
    return
  endif

  " Add the current buffer to the buffer navigation history list of the
  " current window.
  "
  " In case the buffer that is being appended is already the next buffer in
  " the history, ignore it. This happens in case a buffer is loaded that is
  " also the next buffer in the forward browsing history. Thus, this
  " prevents duplicate entries of the same buffer occurring next to each
  " other in the browsing history.
  let w:history_index += 1

  if w:history_index != len(w:history) && w:history[w:history_index] == a:bufnr
    return
  endif

  let w:history = insert(w:history, a:bufnr, w:history_index)
endfunction

" Displays buffer navigation history for the current window.
function s:BufSurfList()
    if s:IsWindowDisabled()
        return
    endif

    call s:CheckConsistency()

    echon 'BufSurf: history: '

    let l:buffer_names = []
    let l:idx = 0
    for l:bufnr in w:history
        let l:buffer_name = bufname(l:bufnr + 0)
        if l:idx == w:history_index
          if len(l:buffer_names) > 0
            let l:s = join(l:buffer_names , ' , ') . ' , '
            echon l:s
          endif
          echohl Search
          echon l:buffer_name
          echohl Normal
          let l:buffer_names = []
        else
          let l:buffer_names = l:buffer_names + [l:buffer_name]
        endif
        let l:idx += 1
    endfor

    if len(l:buffer_names) > 0
      let l:s =  ' , ' . join(l:buffer_names , ' , ')
      echon l:s
    endif
endfunction

" Removes the &bufnr from the history. Updates history_index
" call this per window
function s:BufSurfDeleteInWindow(bufnr)
    if s:IsWindowDisabled()
      return
    endif

    " Remove the buffer; update index
    let l:tail = filter(w:history[w:history_index + 1 : ],
          \             'v:val != ' . a:bufnr)
    let l:head = filter(w:history[0 : w:history_index], 'v:val != ' . a:bufnr)

    let w:history_index = len(l:head) - 1
    let w:history = l:head + l:tail

    " the plugin BuffKill switches to the alternate buffer
    " before wipping, so we make sure we don't have consecutive identical
    " items in history
    if w:history_index > 0 &&
          \ w:history[w:history_index] == w:history[w:history_index - 1]
      call remove(w:history, w:history_index)
      let w:history_index -= 1
    endif

endfunction

" Remove buffer with number bufnr from all navigation histories.
function s:BufSurfDelete(bufnr)
    " if s:IsWindowDisabled()
    "   return
    " endif

    let l:curr_win = winnr()
    windo call s:BufSurfDeleteInWindow(a:bufnr)
    " return to the window we started
    execute l:curr_win . "wincmd w"

endfunction

" Echo a BufSurf message in the Vim status line.
function s:BufSurfEcho(msg, warn)
  if a:warn == 1
      echohl WarningMsg
  endif
  echomsg 'BufSurf: ' . a:msg
  echohl None
endfunction

" Setup the autocommands that handle MRU buffer ordering per window.
augroup BufSurf
  autocmd!

  autocmd BufEnter,WinEnter    * call s:BufSurfAppend(expand('<abuf>'))
  autocmd BufDelete,BufWipeout * call s:BufSurfDelete(expand('<abuf>'))
augroup End
