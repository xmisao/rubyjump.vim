[English](https://github.com/xmisao/rubyjump.vim) / Japanese

RubyJump
=============

RubyJumpはRubyスクリプトを編集するためのvimプラグインです。
バッファ内のメソッド、クラス、モジュール定義に素早くジャンプすることができます。

## デモ

<img src="http://www.xmisao.com/assets/2014_05_11_rubyjump_demo.gif">

## インストール

### 手動

rubyjump.vimを`~/.vim/plugin`ディレクトリにコピーして下さい。

### Vundle

以下を`~/.vimrc`に書いて`:BundleInstall`を実行して下さい。

~~~~
Bundle 'xmisao/rubyjump.vim'
~~~~

## システム要件

RubyJumpはVim 7.4で動作を確認しています。
RubyJumpを動作させるにはVimのRubyインタフェースが有効になっている必要があります。

## 機能

### コマンド

RubyJumpは以下のコマンドをVimに追加します。

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

全てのウィンドウの定義のいずれかへジャンプします。
このコマンドを実行すると画面上部に候補選択ウィンドウが開きます。
Enterキーで候補を確定すると、その名前の定義にジャンプできます。

候補選択ウィンドウではあいまいな補完が可能です。
例えば`foobar`という名前のメソッドは、`foo`、`bar`、`fb`、`oo`といった入力にマッチして補完されます。

#### RubyJumpLocal

カレントウィンドウの定義のいずれかへジャンプします。
他はRubyJumpと同様です。

#### RubyJumpCursor

カーソル下の単語で`RubyJump`を実行して定義へジャンプします。

#### RubyJumpNext

`RubyJump`/`RubyJumpLocal`でジャンプした後に、同名の定義がある場合に、次の定義にジャンプします。

#### RubyJumpPrev

`RubyJump`/`RubyJumpLocal`でジャンプした後に、同名の定義がある場合に、前の定義にジャンプします。

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
- g:rubyjump#enable_ripper
- g:rubyjump#filetypes

#### g:rubyjump#debug

`1`を設定するとデバッグモードを有効にします。
通常は使用しません。

デフォルト値は`0`です。

#### g:rubyjump#enable_ripper

`1`を設定するとRubyパーサのripperを使用します。

このオプションが有効な時、RubyJumpはまずripperによるパースを試み、パースエラーなら正規表現でパースします。

このオプションはRuby 1.9以上を要求します。

デフォルト値はRubyが1.9以上の時は`1`、未満の場合は`0`です。

#### g:rubyjump#filetypes

RubyJumpの対象とするファイルタイプを配列で指定します。

デフォルト値は`['ruby']`です。

### 設定例

~~~~
" for RubyJump

" デバッグモード無効
g:rubyjump#debug = 0

" キーマップ定義
" <Space> RubyJumpを実行
" ; RubyJumpCursorを実行
" Ctrl + n 前方の定義に飛ぶ
" Ctrl + p 後方の定義に飛ぶ
nmap <silent> <Space> <Plug>(rubyjump)
nmap <silent> <C-n> <Plug>(rubyjump_next_forward)
nmap <silent> <C-p> <Plug>(rubyjump_prev_backward)
nmap <silent> ; <Plug>(rubyjump_cursor)
~~~~
