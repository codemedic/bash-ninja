## `go2` - bookmarks for the shell

`go2` is a path bookmark utility that would help you navigate within the filesystem using bookmarks. It comes with auto-completion and bookmark addition command `go2_add`.

Once you `cd` yourself into a path, you can run `go2_add bookmarkName` to add the current working directory into the bookmark. Once added, you can use `go2 bookmarkName` to `cd` into the location, from elsewhere.

The bookmark-name as well as any sub-directories under the location can be auto-completed by the usual bash means. The bookmark-name and its subpath(s) has to be separated by `#`. You can also go a level above (and auto-completed) using `go2 bookmarkName#../`.

See [`go_bookmarks.conf`](go_bookmarks.conf) for some examples. The config is re-read and executed each time you invoke `go2` or the auto-completion, so that the changes are instantaneous.

In order to install this into your profile, edit your `.bashrc` and add the below lines.

    go_projects_conf=$HOME/go_bookmarks.conf
    source $HOME/go.sh