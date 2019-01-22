`open-url` is a wrapper script to make it possible to open URL in an already running browser, rather than the
"default-browser". It is aware of a set of browsers, and has a priorderised list of browsers. When invoked with a URL as
its argument, it will look through the priority list to figure out if one of them is running already. If a running
browser is found, it is used to open the URL. If no running browser is found, it picks the first in the priority list to
open the URL.

## How to setup?

Assuming that you have `~/bin` which is part of your `$PATH` variable, use the commands below to override
"default-browser". This might need further updates for your specific desktop environment.

```
# Create a dekstop entry for open-url by following the instructions here
# https://wiki.archlinux.org/index.php/Desktop_entries
# Then use it as the default web browser
xdg-settings set default-web-browser 'open-url.desktop'

# Some applications will use the below means to invoke default-browser
# Override them so/hoping that these applications are not invoking them by full path
# If you find that they do, you might either have to replace its settings to use the path
# under ~/bin or in worse case scenario, replace them in /usr/bin
ln -sf ~/bin/open-url ~/bin/x-www-browser
ln -sf ~/bin/open-url ~/bin/sensible-browser
ln -sf ~/bin/open-url ~/bin/gnome-www-browser
```

