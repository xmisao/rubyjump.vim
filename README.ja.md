[English](https://github.com/xmisao/rubyjump.vim) / Japanese

rubyjump
=============

rubyjumpはRubyスクリプトを編集するためのvimプラグインです。
バッファ内のメソッド、クラス、モジュール定義に素早くジャンプすることができます。

## デモ

<img src="http://www.xmisao.com/assets/2014_05_02_xrubyjump_demo.gif">

## インストール

### 手動

rubyjump.vimを`~/.vim/plugin`ディレクトリにコピーして下さい。

### Vundle

以下を`~/.vimrc`に書いて`:BundleInstall`を実行して下さい。

~~~~
Bundle 'xmisao/rubyjump.vim'
~~~~

## システム要件

rubyjumpはVim 7.4で動作を確認しています。
rubyjumpを動作させるにはVimのRubyインタフェースが有効になっている必要があります。

## 機能

### コマンド

rubyjumpは以下のコマンドをVimに追加します。

- RubyJump
- RubyJumpLocal
- RubyJumpCursor
- RubyJumpNext
- RubyJumpPrev
- RubyJumpForward
- RubyJumpBackward
- RubyJumpNextForward
- RubyJumpPrevBackward
- RubyJumpVersion

#### RubyJump

開いている全てのウィンドウを対象に、定義へのジャンプを行います。
このコマンドを実行すると画面上部に候補選択ウィンドウが開きます。
Enterキーで候補を確定すると、その名前の定義にジャンプできます。

候補選択ウィンドウではあいまいな補完が可能です。
例えば`foobar`という名前のメソッドは、`foo`、`bar`、`fb`、`oo`といった入力にマッチして補完されます。

#### RubyJumpLocal

カレントウィンドウを対象に、定義へのジャンプを行います。
他はRubyJumpと同様です。

#### RubyJumpCursor

カーソル下の単語で`RubyJump`を実行して定義へジャンプします。

#### RubyJumpNext

`RubyJump`/`RubyJumpLocal`でジャンプした後に、同名の定義がある場合に、次の候補にジャンプします。

#### RubyJumpPrev

`RubyJump`/`RubyJumpLocal`でジャンプした後に、同名の定義がある場合に、前の候補にジャンプします。

#### RubyJumpFoward

カーソル移動を補助するコマンドです。
カーソル位置の前方にある最初の定義にジャンプします。

#### RubyJumpBackward

カーソル位置の後方にある最初の定義にジャンプします。

#### RubyJumpNextForward

ジャンプ直後は`RubyJumpNext`として、その後カーソルが移動されると`RubyJumpForward`として振る舞います。
前方への移動にはこのコマンドを使うことを推奨します。

#### RubyJumpPrevBackward

ジャンプ直後は`RubyJumpPrev`として、その後カーソルが移動されると`RubyJumpBackward`として振る舞います。
後方への移動にはこのコマンドを使うことを推奨します。

#### RubyJumpVersion

RubyJumpのバージョン情報を表示します。

### キーマップ

コマンドと対応させて以下のキーマップを定義しています。
好きなキーに割り当てて使用して下さい。

<table>
<tr><th>キーマップ</th><th>コマンド</th><tr>
<tr><td>&lt;Plug&gt;(rubyjump)</td><td>RubyJump</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_local)</td><td>RubyJumpLocal</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_cursor)</td><td>RubyJumpCursor</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_next)</td><td>RubyJumpNext</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_prev)</td><td>RubyJumpPrev</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_forward)</td><td>RubyJumpForward</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_backward)</td><td>RubyJumpBackward</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_next_forward)</td><td>RubyJumpNextForward</td></tr>
<tr><td>&lt;Plug&gt;(rubyjump_prev_backward)</td><td>RubyJumpPrevBackward</td></tr>
</table>

### グローバル変数

以下のグローバル変数があります。

- g:rubyjump#debug

#### g:rubyjump#debug

`1`を設定するとデバッグモードを有効にします。
通常は使用しません。

### 設定例

~~~~
" デバッグモード無効
g:rubyjump#debug = 0

" キーマップ定義
" ' RubyJumpを実行
" " RubyJumpLocalを実行
" ; RubyJumpCursorを実行
" Ctrl + n 前方の定義に飛ぶ
" Ctrl + p 後方の定義に飛ぶ
nmap ' <Plug>(rubyjump)
autocmd BufNewFile,BufRead *.rb nmap " <Plug>(rubyjump_local)
nmap <C-n> <Plug>(rubyjump_next_forward)
nmap <C-p> <Plug>(rubyjump_prev_backward)
nmap ; <Plug>(rubyjump_cursor)
~~~~
