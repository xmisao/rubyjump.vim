"おまじない
"if exists("g:loaded_xrubyjump")
"  finish
"endif
let g:loaded_xrubyjump = 1

let s:save_cpo = &cpo
set cpo&vim

ruby << RUBY
class XRubyJump
  attr_accessor :index, :list

  def clear
    @index = Hash.new{|h, k| h[k] = [] }
    @list = []
  end
end
$xrubyjump = XRubyJump.new
RUBY

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
  "inoremap <buffer> <Plug>(startXRubyJumpCompletion) <C-R>=XRubyJumpCompletion()<CR>
  " バッファを閉じるautocmdの定義
  autocmd InsertLeave,BufLeave <buffer> :call XRubyJumpWindowClose()
  autocmd CursorMovedI <buffer> :call feedkeys("\<C-x>\<C-u>\<C-p>")
  setlocal completefunc=XRubyJumpCompleteFunc

  call feedkeys('i') " インサートモードに入る
  "call feedkeys("\<Plug>(startXRubyJumpCompletion)") " 補完を開始する
  call feedkeys("\<C-x>\<C-u>")
  call feedkeys("\<C-p>") " 候補を未選択の状態にする
endfunc

" 位置情報と補完候補の初期化
func! XRubyJumpInitialize()
ruby << RUBY
  buf = VIM::Buffer.current
  index = [] # 位置情報
  list = [] # 補完候補
  $xrubyjump.clear
  for i in (1..buf.length)
    if m = buf[i].match(/def (\w+)/)
      name = m[1]
      $xrubyjump.index[name] << {:buffer => buf.number, :row => i, :col => buf[i].index('def')}
    end
    if m = buf[i].match(/class (\w+)/)
      $xrubyjump.index[name] << {:buffer => buf.number, :row => i, :col => buf[i].index('class')}
    end
    if m = buf[i].match(/module (\w+)/)
      $xrubyjump.index[name] << {:buffer => buf.number, :row => i, :col => buf[i].index('module')}
    end
  end
RUBY
endfunc

" Enterキー押下時のハンドラ
func! XRubyJumpEnterKeyHandler()
  let query = getline(1)
  call XRubyJumpWindowClose()

  " 選択した定義にカーソルを移動
ruby << RUBY
  query = VIM::evaluate('query')
  pos = $xrubyjump.index[query][0]
  if pos
    VIM.command("let pos = {'row': #{pos[:row]}, 'col': #{pos[:col]}}")
  else
    VIM.command("let pos = {'row': 0, 'col': 0}")
  end
RUBY
  call cursor(pos['row'], pos['col'])

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

"
func! XRubyJumpCompleteFunc(findstart, base)
  if a:findstart
    return 0
  else
ruby << RUBY
  list = $xrubyjump.index.keys
  query = VIM::evaluate('a:base')
  print query
  query_regexp = Regexp.new(([''] + query.split('') + ['']).join('.*'))
  result = []
  list.each{|item|
    result << item if query_regexp =~ item
  }
  VIM.command('let condidate = [' + result.map{|i| "'#{i}'"}.join(', ') + ']')
RUBY
    return condidate
  endif
endfunc

" *.rbファイルが開かれた時にXRubyJumpコマンドを定義
autocmd BufNewFile,BufRead *.rb command! -buffer XRubyJump :call XRubyJumpWindowOpen()

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
