#include <ruby.h>

/* ruby calls this to load the extension */
void Init_oboe_noop(void) {
  /* assume we haven't yet defined Hola */
//  VALUE klass = rb_define_class("OboeNoop", rb_cObject);
  rb_define_class("OboeNoop", rb_cObject);
}
