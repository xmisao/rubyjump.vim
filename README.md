English / [Japanese](https://github.com/xmisao/rubyjump.vim/blob/master/README.ja.md)

RubyJump
=============

Vim plugin for ruby editing. Quick jump to method, class, module defenitions in buffers.

## Demo

<img src="http://www.xmisao.com/assets/2014_05_11_rubyjump_demo.gif">

## Installation

### Manual Install

copy rubyjump.vim to your `~/.vim/plugin` directory.

### Vundle

write bellow to your `~/.vimrc`. And execute `:BundleInstall`.

~~~~
Bundle 'xmisao/rubyjump.vim'
~~~~

## Requirements

RubyJump is tested on Vim 7.4.
Ruby interface(if_ruby) is required.

## Usage

### Commands

RubyJump add these comamnds to Vim.

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

Jump to a definition in all windows.
Once this command executed, selection window is open above.
Enter key pressed, jump to the definition.

In selection window, you can use ambiguous completion.
For example, method named `foobar` is matches `foo`, `bar`, `fb` or `oo`.

#### RubyJumpLocal

Jump to a definition in current window.

#### RubyJumpCursor

execute `RubyJump` with under cursor word.

#### RubyJumpNext

after `RubyJump` or `RubyJumpLocal`, if same name definitions are there, jump to next definition.

#### RubyJumpPrev

after `RubyJump` or `RubyJumpLocal`, if same name definitions are there, jump to previous definition.

#### RubyJumpFoward

This is support command for cursor moving.
Move to forward definition.

#### RubyJumpBackward

Move to backward definition.

#### RubyJumpNextForward

After jump, this command behaves `RubyJumpNext`.
Else, this command behaves `RubyJumpForward`.
This command is recommended to move to forward.

#### RubyJumpPrevBackward

After jump, this command behaves `RubyJumpPrev`.
Else, this command behaves `RubyJumpBackward`.
This command is recommended to move to backward.

#### RubyJumpVersion

Show RubyJump's version information.

### Keymaps

RubyJump provides these keymaps to Vim.
Keymaps are obverse commands.

<table>
<tr><th>Keymap</th><th>Command</th><tr>
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

### Variables

RubyJump use these variables.

- g:rubyjump#debug
- g:rubyjump#enable_ripper
- g:rubyjump#filetypes

#### g:rubyjump#debug

If set to `1`, debug mode is enabled.

Default value is `0`.

#### g:rubyjump#enable_ripper

If set to `1`, RubyJump use ripper. ripper is parser of Ruby.

If this option enabled, first RubyJump challenge parsing by ripper, if parse error detected, then parse by regular expression.

This option requires over Ruby 1.9.

Default value is `1` in over Ruby 1.9 environment, `0` in under Ruby 1.8 environment.

#### g:rubyjump#filetypes

Specify buffer filetypes that jump target as string array.

Default value is `['ruby']`.

## Configuration Example

~~~~
" for RubyJump

" Disable debug mode
g:rubyjump#debug = 0

" Keymaps
" <Space> execute RubyJump
" ; execute RubyJumpCursor
" Ctrl + n Move to next or forward definition
" Ctrl + p Move to previous or backward definition
nmap <silent> <Space> <Plug>(rubyjump)
nmap <silent> <C-n> <Plug>(rubyjump_next_forward)
nmap <silent> <C-p> <Plug>(rubyjump_prev_backward)
nmap <silent> ; <Plug>(rubyjump_cursor)
~~~~
