"おまじない
"if exists("g:loaded_xrubyjump")
"  finish
"endif
let g:loaded_xrubyjump = 1

let s:save_cpo = &cpo
set cpo&vim

ruby << RUBY
module XRubyJumpVimHelper
  # ウィンドウの番号を返す
  def win_num(window)
    for i in (0..VIM::Window.count - 1)
      if VIM::Window[i] == window
        return i + 1
      end
    end
  end

  # デバッグ用
  def echom(str)
    VIM.command("echom '#{str}'")
  end

  module_function :win_num, :echom
end

class XRubyJump
  attr_accessor :index

  def clear
    @index = Hash.new{|h, k| h[k] = [] }
  end

  def add_index(name, window, row, col)
    @index[name] << {:window => window, :row => row, :col => col}
  end

  def find(win, name)
    pos = @index[name].find{|i| i[:window] == win}
    if pos
      pos[:col] += 2
      pos
    else
      pos = {:row => 0, :col => 0} unless pos
    end
  end

  def get_list(win)
    @index.select{|k, v| v.find{|i| i[:window] == win }}.keys
  end
end
$xrubyjump = XRubyJump.new
RUBY

" 候補選択ウィンドウを開く
func! XRubyJumpWindowOpen()
  " 初期化
  call XRubyJumpInitialize()

  " 候補選択ウィンドウ生成
  1sp
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
  $xrubyjump.clear
  for win in (0..VIM::Window.count - 1)
    buf = VIM::Window[win].buffer
    filetype = VIM.evaluate("getbufvar(#{buf.number}, '&filetype')")
    next if filetype != 'ruby'
    index = [] # 位置情報
    list = [] # 補完候補
    for i in (1..buf.length)
      if m = buf[i].match(/def (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win + 1, i, buf[i].index('def'))
      end
      if m = buf[i].match(/class (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win + 1, i, buf[i].index('class'))
      end
      if m = buf[i].match(/module (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win + 1, i, buf[i].index('module'))
      end
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
  pos = $xrubyjump.find(XRubyJumpVimHelper.win_num(VIM::Window.current), query)
  VIM.command("let pos = {'row': #{pos[:row]}, 'col': #{pos[:col]}}")
  VIM.command("#{pos[:window]}wincmd w")
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

" 候補選択ウィンドウのユーザ補完関数
func! XRubyJumpCompleteFunc(findstart, base)
  if a:findstart
    return 0
  else
ruby << RUBY
  list = $xrubyjump.get_list(XRubyJumpVimHelper.win_num(VIM::Window.current))
  query = VIM::evaluate('a:base')
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
