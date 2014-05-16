scriptencoding utf-8

if !exists('g:rubyjump#debug')
  let g:rubyjump#debug = 0
endif

if !exists('g:rubyjump#enable_ripper')
ruby <<RUBY
  # Ruby 1.9以降ならデフォルトでripperを有効にする
  if RUBY_VERSION >= "1.9"
    VIM::command("let g:rubyjump#enable_ripper = 1")
  else
    VIM::command("let g:rubyjump#enable_ripper = 0")
  end
RUBY
endif

if !exists('g:rubyjump#filetypes')
  " デフォルトでRubyJumpの対象にするファイルタイプはrubyのみ
  let g:rubyjump#filetypes = ['ruby']
endif

"おまじない
if g:rubyjump#debug != 1 " デバッグ時は再読み込みを許容
  if exists("g:loaded_rubyjump")
    finish
  endif
endif
let g:loaded_rubyjump = 1

let s:save_cpo = &cpo
set cpo&vim

ruby << RUBY
require 'ripper' if VIM::evaluate('g:rubyjump#enable_ripper') == 1

class String
  def is(*args)
    args.each{|str|
      return true if self =~ Regexp.new(str)
    }
    return false
  end
end

class VIM::Buffer
  def to_s
    str = ""
    for i in (1..self.length)
      str << self[i] + "\n"
    end
    str
  end
end

# RubyJump用のRubyパーサ
class Parser < Ripper
  # パースエラー時に例外を発生
  def on_parse_error(*args)
    raise 'ParseError'
  end
end

module RubyJump
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

    # g:rubyjump#debugが1ならデバッグメッセージを出力
    def debug(obj)
      flag = VIM.evaluate('g:rubyjump#debug')
      if flag == 1
        message = obj.is_a?(String) ? obj : obj.inspect
        echom("[RubyJumpDebug] " + message)
      end
    end

    # 文字列を表示してメッセージ履歴に残す
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

    # 状態の保存とジャンプ先のインデックスの構築
    def build_index(local)
      # カーソル位置を保存
      $rubyjump.cursor = get_pos()
      debug('cursor: ' + $rubyjump.cursor.inspect)

      # モードを保存
      $rubyjump.local = local
      debug('local: ' + $rubyjump.local.to_s)

      @index = Hash.new{|h, k| h[k] = [] }

      for win in (0..VIM::Window.count - 1)
        # local実行の場合はカレントウィンドウ以外は読み飛ばす
        next if local && win_num(VIM::Window.current) != win

        buf = VIM::Window[win].buffer
        filetype = VIM.evaluate("getbufvar(#{buf.number}, '&filetype')")
        next unless filetype.is(*VIM::evaluate('g:rubyjump#filetypes'))

        if VIM::evaluate("g:rubyjump#enable_ripper") == 1
          # まずripperでパースを試みてパースエラーなら正規表現でパースする
          begin
            parse_by_ripper(win, buf)
          rescue
            parse_by_regexp(win, buf)
          end
        else
          parse_by_regexp(win, buf)
        end
      end
      debug("index: " + $rubyjump.index.inspect)
    end

    # ripperによるパース
    def parse_by_ripper(win, buf)
      debug("parse_by_ripper")
      #debug(buf.to_s)
      Parser.parse(buf.to_s) # パースエラーを検出
      tokens = Parser.lex(buf.to_s)
      tokens.length.times{|i|
        if e = parse_by_ripper0(tokens, i)
          debug(e)
          $rubyjump.add_index(e[1], win, e[0][0], e[0][1] + 1)
        end
      }
    end

    def parse_by_ripper0(tokens, index)
      elm = tokens[index]
      name = nil
      if elm[1] == :on_kw and elm[2].is("def", "class", "module")
        # 名前の終わりまでを読み込む
        tokens[(index + 1)..-1].each{|e|
          if e[1] == :on_nl or # 行末
             e[1] == :on_semicolon or # セミコロン
             (e[1] == :on_op and e[2] == "<") or # クラス継承
             (e[1] == :on_op and e[2] == "<<") or # 特異クラス
             (e[1] == :on_lparen) # 引数の(
            break
          end
          name = e[2] if e[1] == :on_ident or e[1] == :on_const
        }
      end

      if name
        [elm[0], name]
      else
        nil
      end
    end

    # 正規表現によるパース
    def parse_by_regexp(win, buf)
      debug("parse_by_regexp")
      for i in (1..buf.length)
        if name = get_name("def", buf[i])
          $rubyjump.add_index(name, win, i, buf[i].index('def') + 1)
        end
        if name = get_name("class", buf[i])
          $rubyjump.add_index(name, win, i, buf[i].index('class') + 1)
        end
        if name = get_name("module", buf[i])
          $rubyjump.add_index(name, win, i, buf[i].index('module') + 1)
        end
      end
    end

    # 行から定義の名前を抜き出す
    def get_name(type, line)
      full_name = line.slice(/#{type}\s+[\w\.:]+/) # 名前全体 Hoge::Piyo や self.foo など
      return nil unless full_name
      full_name.slice(/\w+$/) # Piyo や foo など
    end

    def add_index(name, window, row, col)
      @index[name] << {:window => window, :row => row, :col => col}
    end

    # nameの候補の座標を返す
    def find(name)
      # RubyJumpLocal時のみウィンドウ番号を使用、グローバルは0
      win = 0
      if $rubyjump.local
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

    # 前後のnum番目の同名の候補にジャンプする
    def next(num)
      # 名前が正しく入力されていない場合は何もしない
      return unless @query && @index[@query] && @index[@query].length > 0

      # RubyJumpLocal時のみウィンドウ番号を使用、グローバルは0
      win = 0
      if $rubyjump.local
        win = win_num(VIM::Window.current)
      end

      # 次の候補の座標へカーソルを移動
      idx = (@last[win][@query] + num) % @index[@query].length
      pos = @index[@query][idx]
      move(pos)
      @last[win][@query] = idx
    end

    # 前方の定義に飛ぶ
    def forward()
      pos = get_pos() 
      definitions = @index.values.flatten.sort_by{|i| i[:row] }
      target = definitions.find{|i| i[:row] > pos[:row] }
      target = definitions[0] unless target
      return unless target
      move(target)
    end

    # 後方の定義に飛ぶ
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
include RubyJump::Helper
$rubyjump = RubyJump::Main.new
RUBY

" 候補選択ウィンドウを開く
func! RubyJumpWindowOpen(local)
  " 初期化
  call RubyJumpInitialize(a:local)

  " 候補選択ウィンドウ生成
  if a:local == 1
    1sp
  else
    topleft 1sp
  endif
  hide enew
  setlocal noswapfile
  file `='[RubyJump]'`

  " Enterキー入力時のマップ定義
  inoremap <buffer> <CR> <CR><C-R>=RubyJumpEnterKeyHandler()<CR>
  " バッファを閉じるautocmdの定義
  autocmd InsertLeave,BufLeave <buffer> :call RubyJumpWindowClose()
  setlocal completefunc=RubyJumpCompleteFunc
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
func! RubyJumpInitialize(local)
ruby << RUBY
  local = VIM::evaluate('a:local') != 0
  $rubyjump.build_index(local)
RUBY
endfunc

" Enterキー押下時のハンドラ
func! RubyJumpEnterKeyHandler()
  let query = getline(1)
  call RubyJumpWindowClose()

  " 選択した定義にカーソルを移動
ruby << RUBY
  query = VIM::evaluate('query')
  $rubyjump.query = query
  debug('query: ' + $rubyjump.query)
  pos = $rubyjump.find(query)
  if pos
    pos = pos.dup
    pos[:col] += 1 # なぜか少しずれるので座標を微調整
    move(pos)
  end
  $rubyjump.jumping = true # ジャンプ中フラグを立てる
  $rubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
  " 移動検出のためのautocmd登録
  autocmd rubyjump CursorMoved * :call RubyJumpCursorMoved()
  return ''
endfunc

func! RubyJumpWindowClose()
  call feedkeys("\<ESC>\<ESC>") " 補完ポップアップを消す
  q! " 候補選択ウィンドウを閉じる
ruby << RUBY
  # カーソル位置を復元
  move($rubyjump.cursor)
RUBY
endfunc

" 候補選択ウィンドウのユーザ補完関数、あいまいな補完を行う
func! RubyJumpCompleteFunc(findstart, base)
ruby << RUBY
  list = $rubyjump.get_list()
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
      return -2 " 本来は -3 が正しい気がするが候補がない時の挙動がおかしいので -2 にしておく
    end
  else
    return {'refresh': 'always', 'words': condidate}
  endif
endfunc

" 同名の次の候補に飛ぶ
func! RubyJumpNext()
ruby << RUBY
  $rubyjump.next(1)
  $rubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
endfunc

" 同名の前の候補に飛ぶ
func! RubyJumpPrev()
ruby << RUBY
  $rubyjump.next(-1)
  $rubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
endfunc

" カーソル下の単語でRubyJumpを実行
func! RubyJumpCursor()
  call RubyJumpInitialize(0)
ruby << RUBY
  query = VIM::evaluate('expand("<cword>")')
  $rubyjump.query = query
  debug('query: ' + $rubyjump.query)
  pos = $rubyjump.find(query)
  move(pos) if pos
  $rubyjump.jumping = true # ジャンプ中フラグを立てる
  $rubyjump.jumptime = Time.now.to_f # ジャンプ時間を更新
RUBY
  " 移動検出のためのautocmd登録
  autocmd rubyjump CursorMoved * :call RubyJumpCursorMoved()
endfunc

" バッファ内の次の候補に飛ぶ
func! RubyJumpForward()
  call RubyJumpInitialize(1)
ruby << RUBY
  $rubyjump.forward()
RUBY
endfunc

" バッファ内の前の候補に飛ぶ
func! RubyJumpBackward()
  call RubyJumpInitialize(1)
ruby << RUBY
  $rubyjump.backward()
RUBY
endfunc

" カーソル移動時のハンドラ
" カーソルが移動されたらジャンプ中のフラグを下ろす
func! RubyJumpCursorMoved()
ruby << RUBY
  debug('cursor moved.')
  if $rubyjump.jumptime
    # 最終ジャンプ時刻から0.1秒未満のイベントは無視する
    # これはcursor()によるカーソル移動が関数から抜けた後に処理されるので
    # ジャンプによる移動とジャンプ後のユーザによる移動を区別できないため
    if Time.now.to_f - $rubyjump.jumptime > 0.1
      $rubyjump.jumping = false # ジャンプ中フラグをクリア
      debug('jumping flag clear.')
      VIM::command("autocmd! rubyjump CursorMoved *") # カーソル移動のautocmdを削除
    end
end
RUBY
endfunc

" ジャンプ中であればRubyJumpNextを
" ジャンプ中でなければRubyJumpForwardを実行する
func! RubyJumpNextForward()
ruby << RUBY
  debug('jumping: ' + $rubyjump.inspect)
  if $rubyjump.jumping
    VIM::command("RubyJumpNext")
  else
    VIM::command("RubyJumpForward")
  end
RUBY
endfunc

" ジャンプ中であればRubyJumpPrevを
" ジャンプ中でなければRubyJumpBackwardを実行する
func! RubyJumpPrevBackward()
ruby << RUBY
  debug('jumping: ' + $rubyjump.inspect)
  if $rubyjump.jumping
    VIM::command("RubyJumpPrev")
  else
    VIM::command("RubyJumpBackward")
  end
RUBY
endfunc

" バージョン情報
func! RubyJumpVersion()
  echo "RubyJump 0.9.2"
endfunc

" 自動コマンドグループを定義
augroup rubyjump

" RubyJumpコマンドを定義(RubyJumpLocalは*.rbの編集中のみ)
autocmd BufNewFile,BufRead *.rb command! -buffer RubyJumpLocal :call RubyJumpWindowOpen(1)
command! RubyJump :call RubyJumpWindowOpen(0)
command! RubyJumpCursor :call RubyJumpCursor()
command! RubyJumpNext :call RubyJumpNext()
command! RubyJumpPrev :call RubyJumpPrev()
command! RubyJumpForward :call RubyJumpForward()
command! RubyJumpBackward :call RubyJumpBackward()
command! RubyJumpNextForward :call RubyJumpNextForward()
command! RubyJumpPrevBackward :call RubyJumpPrevBackward()
command! RubyJumpVersion :call RubyJumpVersion()

" キーマップの定義
map <Plug>(rubyjump_local) :<C-u>call RubyJumpWindowOpen(1)<CR>
map <Plug>(rubyjump) :<C-u>call RubyJumpWindowOpen(0)<CR>
map <Plug>(rubyjump_cursor) :<C-u>call RubyJumpCursor()<CR>
map <Plug>(rubyjump_next) :<C-u>call RubyJumpNext()<CR>
map <Plug>(rubyjump_prev) :<C-u>call RubyJumpPrev()<CR>
map <Plug>(rubyjump_forward) :<C-u>call RubyJumpForward()<CR>
map <Plug>(rubyjump_backward) :<C-u>call RubyJumpBackward()<CR>
map <Plug>(rubyjump_next_forward) :<C-u>call RubyJumpNextForward()<CR>
map <Plug>(rubyjump_prev_backward) :<C-u>call RubyJumpPrevBackward()<CR>

" おまじない
let &cpo = s:save_cpo
unlet s:save_cpo
