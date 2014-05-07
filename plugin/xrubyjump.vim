"おまじない
if g:XRubyJumpDebug != 1 " デバッグ時は再読み込みを許容
  if exists("g:loaded_xrubyjump")
    finish
  endif
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

    # g:XRubyJumpDebugが1ならデバッグメッセージを出力
    def debug(obj)
      flag = VIM.evaluate('g:XRubyJumpDebug')
      if flag == 1
        message = obj.is_a?(String) ? obj : obj.inspect
        echom("XRubyJumpDebug " + message)
      end
    end

    def echom(str)
      VIM.command("echom '#{str}'")
    end

    module_function :win_num, :move, :debug, :echom
  end

  class Main
    attr_accessor :index, :cursor, :last, :query, :local

    def initialize
      @last = Hash.new{|h, k| h[k] = {}}
    end

    def clear
      @index = Hash.new{|h, k| h[k] = [] }
    end

    def add_index(name, window, row, col)
      @index[name] << {:window => window, :row => row, :col => col}
    end

    def find(name)
      # XRubyJumpLocal時のみウィンドウ番号を使用、グローバルは0
      win = 0
      if $xrubyjump.local
        win = win_num(VIM::Window.current)
      end

      idx = @last[win][name] || 0

      # 最後にフォーカスした場所の解決を試みてダメなら0番目の候補で再試行
      pos = nil
      if @index[name].length > idx
        pos = @index[name][idx].dup
      else
        pos = @index[name][0].dup # 再試行はnameの要素がなければnilになる
      end

      @last[win][name] = idx # 最後のフォーカスを更新

      # 座標の微調整
      if pos
        pos[:col] += 2
      end
      pos
    end

    def next(num)
      # 名前が正しく入力されていない場合は何もしない
      return unless @index[@query] && @index[@query].length > 0

      # XRubyJumpLocal時のみウィンドウ番号を使用、グローバルは0
      win = 0
      if $xrubyjump.local
        win = win_num(VIM::Window.current)
      end

      # 次の候補の座標へカーソルを移動
      idx = (@last[win][@query] + num) % @index[@query].length
      pos = @index[@query][idx].dup
      pos[:col] += 1 # 座標の微調整
      move(pos)
      @last[win][@query] = idx
    end

    def get_list()
      @index.keys.sort
    end
  end
end
include XRubyJump::Helper
$xrubyjump = XRubyJump::Main.new
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
  inoremap <buffer> <CR> <CR><C-R>=XRubyJumpEnterKeyHandler()<CR>
  " バッファを閉じるautocmdの定義
  autocmd InsertLeave,BufLeave <buffer> :call XRubyJumpWindowClose()
  setlocal completefunc=XRubyJumpCompleteFunc
  setlocal completeopt=menuone
  " 文字を入力したら補完を開始
  for c in split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_",'\zs')
    exec "inoremap <buffer> " . c . " " . c . "\<C-x>\<C-u>\<C-p><Down>"
  endfor
  " 文字を削除した場合も補完を開始
  inoremap <buffer> <BS> <BS><C-x><C-u><C-p><Down>

  call feedkeys('i') " インサートモードに入る
  call feedkeys("\<C-x>\<C-u>") " 補完を開始する
  call feedkeys("\<C-p>") " 候補を未選択の状態にする
  call feedkeys("\<Down>") " 最初の候補を選択する
endfunc

" 位置情報と補完候補の初期化
func! XRubyJumpInitialize(local)
ruby << RUBY
  # カーソル位置を保存
  win = win_num(VIM::Window.current)
  pos = VIM::evaluate("getpos('.')")
  $xrubyjump.cursor = {:window => win, :row => pos[1], :col => pos[2]}
  debug('cursor: ' + $xrubyjump.cursor.inspect)

  # 初期化
  $xrubyjump.clear
  local = VIM::evaluate('a:local') != 0
  $xrubyjump.local = local
  debug('local: ' + $xrubyjump.local.to_s)
  for win in (0..VIM::Window.count - 1)
    next if local && win_num(VIM::Window.current) != win

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
  debug("index: " + $xrubyjump.index.inspect)
RUBY
endfunc

" Enterキー押下時のハンドラ
func! XRubyJumpEnterKeyHandler()
  let query = getline(1)
  call XRubyJumpWindowClose()

  " 選択した定義にカーソルを移動
ruby << RUBY
  query = VIM::evaluate('query')
  $xrubyjump.query = query
  debug('query: ' + $xrubyjump.query)
  pos = $xrubyjump.find(query)
  move(pos) if pos
RUBY

  return ''
endfunc

func! XRubyJumpWindowClose()
  call feedkeys("\<ESC>\<ESC>") " 補完ポップアップを消す
  q! " 候補選択ウィンドウを閉じる
ruby << RUBY
  # カーソル位置を復元
  move($xrubyjump.cursor)
RUBY
endfunc

" 候補選択ウィンドウのユーザ補完関数、あいまいな補完を行う
func! XRubyJumpCompleteFunc(findstart, base)
ruby << RUBY
  list = $xrubyjump.get_list()
  query = VIM::evaluate('a:base')
  query_regexp = Regexp.new(([''] + query.split('') + ['']).join('.*')) # あいまいな補完のための正規表現
  result = []
  list.each{|item|
    result << item if query_regexp =~ item
  }
  VIM.command('let condidate = [' + result.map{|i| "'#{i}'"}.join(', ') + ']')
RUBY
  if a:findstart
    if len(condidate) > 0
      return 0
    else
      return -3
    end
  else
    return {'refresh': 'always', 'words': condidate}
  endif
endfunc

" 同名の次の候補に飛ぶ
func! XRubyJumpNext()
ruby << RUBY
  $xrubyjump.next(1)
RUBY
endfunc

" 同名の前の候補に飛ぶ
func! XRubyJumpPrev()
ruby << RUBY
  $xrubyjump.next(-1)
RUBY
endfunc

" XRubyJumpコマンドを定義(XRubyJumpLocalは*.rbの編集中のみ)
autocmd BufNewFile,BufRead *.rb command! -buffer XRubyJumpLocal :call XRubyJumpWindowOpen(1)
command! XRubyJump :call XRubyJumpWindowOpen(0)
command! XRubyJumpNext :call XRubyJumpNext()
command! XRubyJumpPrev :call XRubyJumpPrev()

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
