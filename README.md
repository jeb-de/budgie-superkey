# budgie-superkey

## Supporting Superkey+`<number>` behavior to the budgie desktop.

This add support for the fast switching between programs on the budgie desktop, like the behaviour on Windows or Ubunutu.

The `<number>` is a reference to the nth pinned program in the taskbar.

Superkey+`<number>`
- Switch to the pinned program, if already open, else start a new instance for the first time
- If an instance of the program has already the focus, switch to the next instance  
 
Superkey+Alt+`<number>`  
- Like Superkey+`<number>`, but reverse switching between instances  

Superkey+Shift+`<number>` 
- Force creation of a new instance of the pinned program
