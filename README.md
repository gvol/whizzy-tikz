WhizzyTikZ
==========

WhizzyTikZ is still very experimental and the interface _will_ change.
Nevertheless, it has worked for me in a few cases and can make certain
tasks much easier.  If you feel like hacking on it, I would love some
help, otherwise submitting bug reports is also very valuable.

WhizzyTikZ allows you to write TikZ code (with some restrictions), and
then move the nodes with your mouse and have the changes reflected in
the file.  This allows you to create beautiful TikZ diagrams in which
some, or all, or the nodes have a more organic or random looking
placement.

There are several other TikZ editors, but all were unable to do what I
wanted at the time that I tried them.

- [KtikZ](http://kde-apps.org/content/show.php/ktikz?content=63188)
- [TikzEdt](http://www.tikzedt.org/)
- [TikZiT](http://tikzit.sourceforge.net/)

There are many other
[programs which output TikZ](http://www.texample.net/tikz/resources/)
so if you wish to draw a TikZ diagram completely in a GUI, one of
those may be a better choice.

Installation
------------

1. Install Emacs, [AUCTeX](http://www.gnu.org/software/auctex/),
[ActiveDVI](http://advi.inria.fr/) and
[WhizzyTeX](http://cristal.inria.fr/whizzytex/) and get them working.
This can be a non-trivial step.

2. Copy whizzy-tikz.sty to someplace latex can find it, for example,
in the same directory as you LaTeX file.  Alternately, add the
directory where it's found to the `TEXINPUTS` environment variable.

3. In emacs load whizzytex.el as usual and then load whizzy-tikz.el.

Usage
-----

To any nodes you want to be able to move, add the style ADVI.  Someday
you'll be able to set how you want it to be matched (e.g. you have a
custom macro) with the `type` option, but for the moment it looks for
a node with the exact x,y coordinates you gave.  If that fails,
(e.g. you have a macro in one of the coordinates) there is another
looser matching that may or may not succeed.  This matching is less
tested since I didn't need it for my application.

You can specify how many digits after the decimal place you would like
(default=4) by setting the precision parameter.  You can also set
whether the node should be moved (default), or duplicated.  The
duplication is very simple, it just copies the line where it found a
match and places the new (moved) version after that line.

    \node[ADVI={precision=0,duplicate=yes}] (3,5) {factory};


Known Bugs
----------

- If you use a macro in a coordinate it won't update the value of the
macro.  Instead it updates the node directly, overwriting the call the
macro.  This can simultaneously be considered a bug and a feature, but
it does mean that it will not work with constructs like `\foreach`.

    \newcommand{\y}{3}
    \node (2,\y);

- You have to specify which nodes are editable.  Though of course you
can use something like

    \tikzstyle{every node} = [ADVI]

- Sometimes the line number is wrong.  I think this might be because
of slicing.  I'm not sure how to track it down.

- There is only support for nodes, not rectangles, circles, etc.

- It is not properly packaged or documented.
