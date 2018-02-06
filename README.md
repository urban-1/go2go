# Go2Go

Yet Another Go Virtual Environment Manager...

## What?

- Manages Go virtual environments
- Installs Go and Glide when needed

[![asciicast](https://asciinema.org/a/QqQKrMNXBSzXEGoB0eaJ87jWS.png)](https://asciinema.org/a/QqQKrMNXBSzXEGoB0eaJ87jWS)

The commands used (more or less...)

```
# Alias it (optional)
alias g2g=/home/urban/git/github/go2go/go2go.sh

# Install a version of Go
g2g install 1.9

# List versions
g2g lsvers

# Create a new environment named "go-test-1"
g2g env go-test-1 1.9

# List environemnt
g2g lsenvs

# Create a new environment with a Go version not yet installed
g2g env go-test-2 1.8

g2g lsenvs
g2g lsvers

# Activate
. <(g2g activate go-test-1)
go version

. <(g2g activate go-test-2)
go version
go_away

# clean-up
g2g rmenv go-test-2
g2g lsenvs

g2g rmenv go-test-1
g2g uninstall 1.8
g2g lsvers

g2g uninstall 1.9
g2g lsenvs
g2g lsvers
exit

```

### MAC users

```
eval "$(./go2go.sh activate go-dev)"

# OR

. /dev/stdin <<< "$(./go2go.sh activate go-dev)"
```


## Why?

- For fun...
- Single script, no dependencies

## References

**All installation code is from:
https://github.com/kaneshin/goenv/blob/master/libexec/goenv-install**
