This package implements the port, path, encoding, printing, and
formatting layer. It can be run in a host Racket with `make demo`, but
it's meant to be compiled for use in Racket on Chez Scheme; see
"../cs/README.txt".

Core error support must be provided as a more primitive layer,
including the exception structures and error functions that do not
involve formatting, such as `raise-argument-error`. The more primitive
layer should provide a `error-value->string-handler` paramemeter, but
this layer sets that parameter (so the primitive error function slike
`raise-argument-error` won't work right until this layer is loaded).
