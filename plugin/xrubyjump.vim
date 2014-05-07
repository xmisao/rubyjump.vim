"おまじない
if exists("g:loaded_xrubyjump")
  finish
endif
let g:loaded_xrubyjump = 1

let s:save_cpo = &cpo
set cpo&vim

ruby << RUBY
module XRubyJump
  module Helper
    # ウィンドウの番号を返す
    def win_num(window)
      for i in (0..VIM::Window.count - 1)
        if VIM::Window[i] == window
          return i
        end
      end
    end

    # 指定したウィンドウ、行、列にカーソルを移動させる
    def move(pos)
      VIM.command("#{pos[:window] + 1}wincmd w")
      VIM.command("call cursor(#{pos[:row]}, #{pos[:col]})")
    end

    # デバッグ用
    def echom(str)
      VIM.command("echom '#{str}'")
    end

    module_function :win_num, :move, :echom
  end

  class Main
    attr_accessor :index, :cursor

    def clear
      @index = Hash.new{|h, k| h[k] = [] }
    end

    def add_index(name, window, row, col)
      @index[name] << {:window => window, :row => row, :col => col}
    end

    def find(win, name)
      pos = @index[name].first
      if pos
        pos[:col] += 2
        pos
      else
        nil
      end
    end

    def get_list(win)
      #@index.select{|k, v| v.find{|i| i[:window] == win }}.keys
      @index.keys
    end
  end
end
include XRubyJump
$xrubyjump = Main.new
RUBY

" 候補選択ウィンドウを開く
func! XRubyJumpWindowOpen(local)
  " 初期化
  call XRubyJumpInitialize(a:local)

  " 候補選択ウィンドウ生成
  if a:local == 1
    1sp
  else
    topleft 1sp
  endif
  hide enew
  setlocal noswapfile
  file `='[xRubyJump]'`

  " Enterキー入力時のマップ定義
  inoremap <buffer> <CR> <C-R>=XRubyJumpEnterKeyHandler()<CR>
  " バッファを閉じるautocmdの定義
  autocmd InsertLeave,BufLeave <buffer> :call XRubyJumpWindowClose()
  autocmd CursorMovedI <buffer> :call feedkeys("\<C-x>\<C-u>\<C-p>")
  setlocal completefunc=XRubyJumpCompleteFunc

  call feedkeys('i') " インサートモードに入る
  call feedkeys("\<C-x>\<C-u>") " 補完を開始する
  call feedkeys("\<C-p>") " 候補を未選択の状態にする
endfunc

" 位置情報と補完候補の初期化
func! XRubyJumpInitialize(local)
ruby << RUBY
  # カーソル位置を保存
  win = Helper.win_num(VIM::Window.current)
  pos = VIM::evaluate("getpos('.')")
  $xrubyjump.cursor = {:window => win, :row => pos[1], :col => pos[2]}
  Helper.echom($xrubyjump.cursor.inspect)

  # 初期化
  $xrubyjump.clear
  local = VIM::evaluate('a:local') != 0
  for win in (0..VIM::Window.count - 1)
    next if local && Helper.win_num(VIM::Window.current) != win

    buf = VIM::Window[win].buffer
    filetype = VIM.evaluate("getbufvar(#{buf.number}, '&filetype')")
    next if filetype != 'ruby'
    index = [] # 位置情報
    list = [] # 補完候補
    for i in (1..buf.length)
      if m = buf[i].match(/def (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win, i, buf[i].index('def'))
      end
      if m = buf[i].match(/class (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win, i, buf[i].index('class'))
      end
      if m = buf[i].match(/module (\w+)/)
        name = m[1]
        $xrubyjump.add_index(name, win, i, buf[i].index('module'))
      end
    end
  end
  Helper.echom("Index: " + $xrubyjump.index.inspect)
RUBY
endfunc

" Enterキー押下時のハンドラ
func! XRubyJumpEnterKeyHandler()
  let query = getline(1)
  call XRubyJumpWindowClose()

  " 選択した定義にカーソルを移動
ruby << RUBY
  query = VIM::evaluate('query')
  pos = $xrubyjump.find(Helper.win_num(VIM::Window.current), query)
  Helper.move(pos) if pos
RUBY

  return ''
endfunc

func! XRubyJumpWindowClose()
  call feedkeys("\<ESC>\<ESC>") " 補完ポップアップを消す
  q! " 候補選択ウィンドウを閉じる
ruby << RUBY
  # カーソル位置を復元
  Helper.move($xrubyjump.cursor)
RUBY
endfunc

" 候補選択ウィンドウのユーザ補完関数、あいまいな補完を行う
func! XRubyJumpCompleteFunc(findstart, base)
  if a:findstart
    return 0
  else
ruby << RUBY
  list = $xrubyjump.get_list(Helper.win_num(VIM::Window.current))
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

" XRubyJumpコマンドを定義(XRubyJumpLocalは*.rbの編集中のみ)
autocmd BufNewFile,BufRead *.rb command! -buffer XRubyJumpLocal :call XRubyJumpWindowOpen(1)
command! -buffer XRubyJump :call XRubyJumpWindowOpen(0)

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
