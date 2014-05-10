if !exists('g:xrubyjump#debug')
  let g:xrubyjump#debug = 0
endif

"おまじない
if g:xrubyjump#debug != 1 " デバッグ時は再読み込みを許容
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
    # カーソルの座標を返す
    def get_pos()
      win = win_num(VIM::Window.current)
      pos = VIM::evaluate("getpos('.')")
      {:window => win, :row => pos[1], :col => pos[2]}
    end

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
      debug('pos: ' + pos.inspect)
      VIM.command("#{pos[:window] + 1}wincmd w")
      debug('command: ' + "call cursor(#{pos[:row]}, #{pos[:col]})")
      VIM.command("call cursor(#{pos[:row]}, #{pos[:col]})")
    end

    # g:XRubyJumpDebugが1ならデバッグメッセージを出力
    def debug(obj)
      flag = VIM.evaluate('g:xrubyjump#debug')
      if flag == 1
        message = obj.is_a?(String) ? obj : obj.inspect
        echom("[XRubyJumpDebug] " + message)
      end
    end

    # 文字列を表示し
    def echom(str)
      VIM.command("echom '#{str}'")
    end

    module_function :win_num, :move, :debug, :echom
  end

  class Main
    attr_accessor :index, :cursor, :last, :query, :local, :jumping, :jumptime

    def initialize
      @last = Hash.new{|h, k| h[k] = {}}
    end

    def build_index(local)
      # カーソル位置を保存
      $xrubyjump.cursor = get_pos()
      debug('cursor: ' + $xrubyjump.cursor.inspect)

      # 初期化
      @index = Hash.new{|h, k| h[k] = [] }
      $xrubyjump.local = local
      debug('local: ' + $xrubyjump.local.to_s)
      for win in (0..VIM::Window.count - 1)
        # local実行の場合はカレントウィンドウ以外は読み飛ばす
        next if local && win_num(VIM::Window.current) != win

        buf = VIM::Window[win].buffer
        filetype = VIM.evaluate("getbufvar(#{buf.number}, '&filetype')")
        next if filetype != 'ruby'
        index = [] # 位置情報
        list = [] # 補完候補
        for i in (1..buf.length)
          if m = buf[i].match(/def (\w+)/)
            name = m[1]
            $xrubyjump.add_index(name, win, i, buf[i].index('def') + 1)
          end
          if m = buf[i].match(/class (\w+)/)
            name = m[1]
            $xrubyjump.add_index(name, win, i, buf[i].index('class') + 1)
          end
          if m = buf[i].match(/module (\w+)/)
            name = m[1]
            $xrubyjump.add_index(name, win, i, buf[i].index('module') + 1)
          end
        end
      end
      debug("index: " + $xrubyjump.index.inspect)
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
        pos = @index[name][idx]
      else
        pos = @index[name][0] # 再試行はnameの要素がなければnilになる
      end

      @last[win][name] = idx # 最後のフォーカスを更新

      pos
    end

    def next(num)
      # 名前が正しく入力されていない場合は何もしない
      return unless @query && @index[@query] && @index[@query].length > 0

      # XRubyJumpLocal時のみウィンドウ番号を使用、グローバルは0
      win = 0
      if $xrubyjump.local
        win = win_num(VIM::Window.current)
      end

      # 次の候補の座標へカーソルを移動
      idx = (@last[win][@query] + num) % @index[@query].length
      pos = @index[@query][idx]
      move(pos)
      @last[win][@query] = idx
    end

    def forward()
      pos = get_pos() 
      definitions = @index.values.flatten.sort_by{|i| i[:row] }
      target = definitions.find{|i| i[:row] > pos[:row] }
      target = definitions[0] unless target
      return unless target
      move(target)
    end

    def backward()
      pos = get_pos() 
      definitions = @index.values.flatten.sort_by{|i| i[:row] * -1 }
      target = definitions.find{|i| i[:row] < pos[:row] }
      target = definitions[0] unless target
      return unless target
      move(target)
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
  for c in split("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789",'\zs')
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
  local = VIM::evaluate('a:local') != 0
  $xrubyjump.build_index(local)
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
  if pos
    pos = pos.dup
    pos[:col] += 1 # なぜか少しずれるので座標を微調整
    move(pos)
  end
  $xrubyjump.jumping = true # ジャンプ中フラグを立てる
  $xrubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
  " 移動検出のためのautocmd登録
  autocmd xrubyjump CursorMoved * :call XRubyJumpCursorMoved()
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
  $xrubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
endfunc

" 同名の前の候補に飛ぶ
func! XRubyJumpPrev()
ruby << RUBY
  $xrubyjump.next(-1)
  $xrubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
endfunc

" カーソル下の単語でXRubyJumpを実行
func! XRubyJumpCursor()
  call XRubyJumpInitialize(0)
ruby << RUBY
  query = VIM::evaluate('expand("<cword>")')
  $xrubyjump.query = query
  debug('query: ' + $xrubyjump.query)
  pos = $xrubyjump.find(query)
  move(pos) if pos
  $xrubyjump.jumping = true # ジャンプ中フラグを立てる
  $xrubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
  " 移動検出のためのautocmd登録
  autocmd xrubyjump CursorMoved * :call XRubyJumpCursorMoved()
endfunc

" バッファ内の次の候補に飛ぶ
func! XRubyJumpForward()
  call XRubyJumpInitialize(1)
ruby << RUBY
  $xrubyjump.forward()
RUBY
endfunc

" バッファ内の前の候補に飛ぶ
func! XRubyJumpBackward()
  call XRubyJumpInitialize(1)
ruby << RUBY
  $xrubyjump.backward()
RUBY
endfunc

func! XRubyJumpCursorMoved()
ruby << RUBY
  debug('cursor moved.')
  if $xrubyjump.jumptime
    # 最終ジャンプ時刻から0.1秒未満のイベントは無視する
    # これはcursor()によるカーソル移動が関数から抜けた後に処理されるので
    # ジャンプによる移動とジャンプ後のユーザによる移動を区別できないため
    if Time.now.to_f - $xrubyjump.jumptime > 0.1
      $xrubyjump.jumping = false # ジャンプ中フラグをクリア
      debug('jumping flag clear.')
      VIM::command("autocmd! xrubyjump CursorMoved *") # カーソル移動のautocmdを削除
    end
end
RUBY
endfunc

" ジャンプ中であればXRubyJumpNextを
" ジャンプ中でなければXRubyJumpForwardを実行する
func! XRubyJumpNextForward()
ruby << RUBY
  debug('jumping: ' + $xrubyjump.inspect)
  if $xrubyjump.jumping
    VIM::command("XRubyJumpNext")
  else
    VIM::command("XRubyJumpForward")
  end
RUBY
endfunc

" ジャンプ中であればXRubyJumpPrevを
" ジャンプ中でなければXRubyJumpBackwardを実行する
func! XRubyJumpPrevBackward()
ruby << RUBY
  debug('jumping: ' + $xrubyjump.inspect)
  if $xrubyjump.jumping
    VIM::command("XRubyJumpPrev")
  else
    VIM::command("XRubyJumpBackward")
  end
RUBY
endfunc

" バージョン情報
func! XRubyJumpVersion()
  echo "XRubyJump 0.9.0"
endfunc

" 自動コマンドグループを定義
augroup xrubyjump

" XRubyJumpコマンドを定義(XRubyJumpLocalは*.rbの編集中のみ)
autocmd BufNewFile,BufRead *.rb command! -buffer XRubyJumpLocal :call XRubyJumpWindowOpen(1)
command! XRubyJump :call XRubyJumpWindowOpen(0)
command! XRubyJumpCursor :call XRubyJumpCursor()
command! XRubyJumpNext :call XRubyJumpNext()
command! XRubyJumpPrev :call XRubyJumpPrev()
command! XRubyJumpForward :call XRubyJumpForward()
command! XRubyJumpBackward :call XRubyJumpBackward()
command! XRubyJumpNextForward :call XRubyJumpNextForward()
command! XRubyJumpPrevBackward :call XRubyJumpPrevBackward()
command! XRubyJumpVersion :call XRubyJumpVersion()

" キーマップの定義
map <Plug>(xrubyjump_local) :<C-u>call XRubyJumpWindowOpen(1)<CR>
map <Plug>(xrubyjump) :<C-u>call XRubyJumpWindowOpen(0)<CR>
map <Plug>(xrubyjump_cursor) :<C-u>call XRubyJumpCursor()<CR>
map <Plug>(xrubyjump_next) :<C-u>call XRubyJumpNext()<CR>
map <Plug>(xrubyjump_prev) :<C-u>call XRubyJumpPrev()<CR>
map <Plug>(xrubyjump_forward) :<C-u>call XRubyJumpForward()<CR>
map <Plug>(xrubyjump_backward) :<C-u>call XRubyJumpBackward()<CR>
map <Plug>(xrubyjump_next_forward) :<C-u>call XRubyJumpNextForward()<CR>
map <Plug>(xrubyjump_prev_backward) :<C-u>call XRubyJumpPrevBackward()<CR>

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
