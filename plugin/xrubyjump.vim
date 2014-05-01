"おまじない
if exists("g:loaded_xrubyjump")
  finish
endif
let g:loaded_xrubyjump = 1

let s:save_cpo = &cpo
set cpo&vim

" 候補選択ウィンドウを開く
func! XRubyJumpWindowOpen()
  " 初期化
  call XRubyJumpInitialize()

  " 候補選択ウィンドウ生成
  sp
  resize 1
  hide enew
  setlocal noswapfile
  file `='[xRubyJump]'`

  " Enterキー入力時のマップ定義
  inoremap <buffer> <CR> <C-R>=XRubyJumpEnterKeyHandler()<CR>
  " 補完開始用のマップ定義
  inoremap <buffer> <Plug>(startXRubyJumpCompletion) <C-R>=XRubyJumpCompletion()<CR>
  " バッファを閉じるautocmdの定義
  autocmd InsertLeave,BufLeave <buffer> :call XRubyJumpWindowClose()

  call feedkeys('i') " インサートモードに入る
  call feedkeys("\<Plug>(startXRubyJumpCompletion)") " 補完を開始する
  call feedkeys("\<C-p>") " 候補を未選択の状態にする
endfunc

" 位置情報と補完候補の初期化
func! XRubyJumpInitialize()
ruby << RUBY
  buf = VIM::Buffer.current
  index = [] # 位置情報
  list = [] # 補完候補
  for i in (1..buf.length)
    if m = buf[i].match(/def (\w+)/)
      index << "'#{m[1]}': [#{i}, #{buf[i].index('def') + 2}]"
      list << "'#{m[1]}'"
    end
    if m = buf[i].match(/class (\w+)/)
      index << "'#{m[1]}': [#{i}, #{buf[i].index('class') + 2}]"
      list << "'#{m[1]}'"
    end
    if m = buf[i].match(/module (\w+)/)
      index << "'#{m[1]}': [#{i}, #{buf[i].index('module') + 2}]"
      list << "'#{m[1]}'"
    end
  end
  VIM.command('let g:XRubyJumpIndex = {' + index.join(', ') + '}')
  VIM.command('let g:XRubyJumpList = [' + list.sort.uniq.join(', ') + ']')
RUBY
endfunc

" Enterキー押下時のハンドラ
func! XRubyJumpEnterKeyHandler()
  let query = getline(1)
  call XRubyJumpWindowClose()

  " 選択した定義にカーソルを移動
  let pos = get(g:XRubyJumpIndex, query, [0, 0])
  call cursor(pos[0], pos[1])

  return ''
endfunc

func! XRubyJumpWindowClose()
  call feedkeys("\<ESC>\<ESC>") " 補完ポップアップを消す
  q! " 候補選択ウィンドウを閉じる
endfunc

" 候補選択ウィンドウの補完処理
func! XRubyJumpCompletion()
  call complete(col('.'), g:XRubyJumpList)
  return ''
endfunc

" *.rbファイルが開かれた時にXRubyJumpコマンドを定義
autocmd BufNewFile,BufRead *.rb command! -buffer XRubyJump :call XRubyJumpWindowOpen()

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
