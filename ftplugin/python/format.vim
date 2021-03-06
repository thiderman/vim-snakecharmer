let s:opening = '[({:\[]\s*\(#.*\)\?$'
let s:closing = '^\s*[)}\]]\+\s*$'

function! s:debug(s)
  echo a:s
  call append('$', a:s)
endfunction

function! s:strip(s, ...)
  let string = a:0 ? substitute(a:s, ',\s*$', '', 'g') : a:s
  return substitute(string, '\(^\s*\|\s*$\)', '', 'g')
endfunction

function! s:indent(lines, shift)
  return map(a:lines, 'repeat(" ", a:shift + &sw) . s:strip(v:val) . ","')
endfunction

function! s:replace(lnum, data)
  call setline(a:lnum, a:data[0])
  if len(a:data) > 1
    call append(a:lnum, a:data[1:])
  endif
endfunction

function! PythonFormatExpr(lnum, count, char) abort
  let line = getline(a:lnum)
  let linelength = len(line)
  let shift = indent(a:lnum)
  let insertion = a:char != ""
  let pos = getpos('.')

  " Not yet above the textwidth and an insertion has been made;
  " nothing should be done.
  if linelength <= &tw && insertion
    return
  endif

  " If this matches, we have a long statement that is over the line
  let match = matchlist(line, '^\(.*[({\[]\)\(.\{-}\)\([)}\]]\s*\)$')
  if match != []
    let start = match[1]
    let end = match[3]

    let spl = split(match[2], ',\s*')
    let data = insert(s:indent(spl, shift), start)

    if end == ""
      let end = ")"
    endif
    let end = repeat(' ', shift) . end
    let data = add(data, end)

    " Set the line to the newly formatted ones
    call s:replace(a:lnum, data)

    if insertion
      " If this was an insertion, make sure to retain the cursor position.
      let line_offset = 1
      let col_offset = pos[2] - len(start)

      " Calculate where to put the cursor. Decrease the column offset until
      while col_offset > len(s:strip(data[line_offset]))
        " The +1 is to account for the last space
        let col_offset -= len(s:strip(data[line_offset])) + 1
        let line_offset += 1
      endwhile

      let pos[1] += line_offset
      let pos[2] = shift + &sw + col_offset
    else
      " If not, place the cursor on the beginning of the first item line
      let pos[1] += 1
      let pos[2] = shift + &sw + 1
    endif
    call setpos('.', pos)
    return
  endif

  if a:count
    let lines = getline(a:lnum, a:lnum + a:count - 1)
    " Check if we are formatting a block that looks like a long call
    if lines[0] =~ s:opening && lines[-1] =~ s:closing
      let content = []
      for line in lines[1:-2]
        let content = extend(content, split(line, ','))
      endfor
      let content = map(content, "s:strip(v:val, 1)")
      let closer = s:strip(lines[-1])
      let final = lines[0] . join(content, ', ') . closer

      " If the compressed line is short enough to fit on one line, just fold
      " them all back into one.
      if len(final) < &tw
        exe '.+1,.+'.(a:count - 1).'delete'
        call setline(a:lnum, final)

        " Reset the position to be on the beginning of the first argument
        let pos = getpos('.')
        let pos[1] = a:lnum
        let pos[2] = len(lines[0]) + 1
        call setpos('.', pos)
      else
        exe 'silent .+1,.+'.(a:count - 1).'delete'
        let content = s:indent(content, shift)
        let data = lines[0:0] + content + lines[-1:-1]
        call s:replace(a:lnum, data)

        " If not, place the cursor on the beginning of the first item line
        let pos[1] += 1
        let pos[2] = shift + &sw + 1
      endif
    endif
  endif
endfunction

if &ft == "python" && exists('g:snakeskin_formatting')
  setl fex=PythonFormatExpr\(v:lnum,\ v:count,\ v:char\)
endif
