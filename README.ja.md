[English](https://github.com/xmisao/xrubyjump.vim) / Japanese

xrubyjump.vim
=============

xrubyjump.vimはRubyスクリプトを編集するためのvimプラグインです。
バッファ内のメソッド、クラス、モジュール定義に素早くジャンプすることができます。

## デモ

<img src="http://www.xmisao.com/assets/2014_05_02_xrubyjump_demo.gif">

## インストール

### 手動

xrubyjump.vimを`~/.vim/plugin`ディレクトリにコピーして下さい。

### Vundle

以下を`~/.vimrc`に書いて`:BundleInstall`を実行して下さい。

~~~~
Bundle 'xmisao/xrubyjump.vim'
~~~~

## システム要件

xrubyjump.vimはVim 7.4で動作を確認しています。
xrubyjump.vimを動作させるにはVimのRubyインタフェースが有効になっている必要があります。

## 機能

### コマンド

xrubyjump.vimは以下のコマンドをVimに追加します。

- XRubyJump
- XRubyJumpLocal
- XRubyJumpCursor
- XRubyJumpNext
- XRubyJumpPrev
- XRubyJumpForward
- XRubyJumpBackward
- XRubyJumpNextForward
- XRubyJumpPrevBackward
- XRubyJumpVersion

#### XRubyJump

開いている全てのバッファを対象に定義の検索とジャンプを行います。
このコマンドを実行すると画面上部に候補選択ウィンドウが開き、ジャンプ先を入力できます。

候補選択ウィンドウではあいまいな補完が可能です。
例えば`foobar`という名前のメソッドは、`foo`、`bar`、`fb`、`oo`といった入力にマッチして補完されます。

#### XRubyJumpLocal

カレントウィンドウを対象に定義の検索とジャンプを行います。
このコマンドを実行するとバッファ上部に候補選択ウィンドウが開き、ジャンプ先を入力できます。
他はXRubyJumpと同様です。

#### XRubyJumpCursor

カーソル下の単語で`XRubyJump`を実行して定義へジャンプします。

#### XRubyJumpNext

`XRubyJump`/`XRubyJumpLocal`でジャンプした後に、同名の定義がある場合に、次の候補にジャンプします。

#### XRubyJumpPrev

`XRubyJump`/`XRubyJumpLocal`でジャンプした後に、同名の定義がある場合に、前の候補にジャンプします。

#### XRubyJumpFoward

カーソル移動を補助するコマンドです。
カーソル位置の前方にある最初の定義にジャンプします。

#### XRubyJumpBackward

カーソル移動を補助するコマンドです。
カーソル位置の後方にある最初の定義にジャンプします。

#### XRubyJumpNextForward

ジャンプ直後は`XRubyJumpNext`として、その後カーソルが移動されると`XRubyJumpForward`として振る舞うコマンドです。
前方への移動にはこのコマンドを使うことを推奨します。

#### XRubyJumpPrevBackward

ジャンプ直後は`XRubyJumpPrev`として、その後カーソルが移動されると`XRubyJumpBackward`として振る舞うコマンドです。
後方への移動にはこのコマンドを使うことを推奨します。

#### XRubyJumpVersion

XRubyJumpのバージョン情報を表示します。

### キーマップ

コマンドと対応させて以下のキーマップを定義しています。
好きなキーに割り当てて使用して下さい。

<table>
<tr><th>キーマップ</th><th>コマンド</th><tr>
<tr><td>&lt;Plug&gt;(xrubyjump)</td><td>XRubyJump</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_local)</td><td>XRubyJumpLocal</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_cursor)</td><td>XRubyJumpCursor</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_next)</td><td>XRubyJumpNext</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_prev)</td><td>XRubyJumpPrev</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_forward)</td><td>XRubyJumpForward</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_backward)</td><td>XRubyJumpBackward</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_next_forward)</td><td>XRubyJumpNextForward</td></tr>
<tr><td>&lt;Plug&gt;(xrubyjump_prev_backward)</td><td>XRubyJumpPrevBackward</td></tr>
</table>

### グローバル変数

以下のグローバル変数があります。

- g:xrubyjump#debug

#### g:xrubyjump#debug

`1`を設定するとデバッグモードを有効にします。
通常は使用しません。

### 設定例

~~~~
" デバッグモード無効
g:xrubyjump#debug = 0

" キーマップ定義
" ' XRubyjumpを実行
" " XRubyJumpLocalを実行
" ; XRubyJumpCursorを実行
" Ctrl + n 前方の定義に飛ぶ
" Ctrl + p 後方の定義に飛ぶ
nmap ' <Plug>(xrubyjump)
autocmd BufNewFile,BufRead *.rb nmap " <Plug>(xrubyjump_local)
nmap <C-n> <Plug>(xrubyjump_next_forward)
nmap <C-p> <Plug>(xrubyjump_prev_backward)
nmap ; <Plug>(xrubyjump_cursor)
~~~~
