# bash-ninja

Some utility bash scripts that can be loaded into your bash profile to make your life more enjoyable.


## Go command - go go go !

Say you have more than a few folder locations in which you do your coding etc, and you love living inside the terminal window, then look no further. Go will make your life easier.

You will need to list all the locations that you want to set short cuts for into a text file and then assign each of them to a variable of the form `'cd_*'`
So for example, if you have libninja source code checked out into `$HOME/svn/common/c++/libninja`, you can add the below line to set the shortcut.

    cd_ninja=$HOME/svn/common/c++/libninja

I have added a sample file called go_bookmarks.conf which does a little more than this. It also has the facility to switch between two locations that has the same folder layout. I had to device it to mitigate my madness with git-svn for regular check-ins and final checkin into the official svn repo.
In that case, `go git ninja` would take me to libninja under git and `go svn ninja` would take me to the svn checkout.

In order to install this into your world, edit your `.bashrc` and add the below lines.

    go_projects_conf=$HOME/go_bookmarks.conf
    source $HOME/go.sh

The autocompletion is can be also used to lookup paths that start at the `cd_root`. So if you do `go /<TAB><TAB>`, it will fill in the first levels. This basically minimises the the need to add bookmarks to each and every project location in the source tree. This also works for paths under the bookmarked location. So if you have a bookmark `tests` to the below location; you can type `go tests#Debug` to `cd` into the `Debug` folder.

    cpp-tests
    +-- -
    +-- boost_exceptions.cpp
    +-- boost_time.cpp
    +-- Debug/
    |   +-- cpp-tests.d
    |   +-- cpp-tests.o
    |   +-- makefile
    |   +-- objects.mk
    |   +-- sources.mk
    |   +-- subdir.mk
    +-- tokenizer.cpp
    +-- weak_set.cpp


## License

<a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/deed.en_US"><img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by-sa/3.0/88x31.png" /></a><br /><span xmlns:dct="http://purl.org/dc/terms/" property="dct:title">Bash Ninja</span> by <a xmlns:cc="http://creativecommons.org/ns#" href="https://github.com/codemedic/bash-ninja" property="cc:attributionName" rel="cc:attributionURL">Dino Korah</a> is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/3.0/deed.en_US">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>.<br />Based on a work at <a xmlns:dct="http://purl.org/dc/terms/" href="https://github.com/codemedic/bash-ninja" rel="dct:source">https://github.com/codemedic/bash-ninja</a>
