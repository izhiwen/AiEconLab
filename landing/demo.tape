Output landing/demo.gif

Set FontSize 18
Set Width 1000
Set Height 560
Set Theme "Builtin Solarized Dark"
Set Padding 18
Set PlaybackSpeed 1.0

Hide
Type "cd /tmp && rm -rf ael-landing-demo && mkdir ael-landing-demo && cd ael-landing-demo"
Enter
Type "git init -q -b main && git config user.email demo@example.com && git config user.name Demo"
Enter
Type "echo '# Demo paper' > README.md && git add README.md && git commit -q -m 'initial'"
Enter
Type 'export PATH="$OLDPWD:$OLDPWD/tests/fixtures/demo-bin:$PATH"'
Enter
Type 'export AEL_AIPLUS_BIN="$OLDPWD/tests/fixtures/demo-bin/demo-support"'
Enter
Type "clear"
Enter
Show

Type "ael install"
Sleep 500ms
Enter
Sleep 1600ms

Type 'ael talk advisor "What is your role?"'
Sleep 500ms
Enter
Sleep 2500ms

Type "ael status"
Sleep 500ms
Enter
Sleep 1200ms
