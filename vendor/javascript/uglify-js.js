// uglify-js@1.2.5 downloaded from https://ga.jspm.io/npm:uglify-js@1.2.5/uglify-js.js

import{d as e}from"./_/c887b8dc.js";import{d as r}from"./_/e24efd4c.js";var s={},a=false;function dew(){if(a)return s;a=true;function uglify(e,r){r||(r={});var s=uglify.parser;var a=uglify.uglify;var i=s.parse(e,r.strict_semicolons);i=a.ast_mangle(i,r.mangle_options);i=a.ast_squeeze(i,r.squeeze_options);var t=a.gen_code(i,r.gen_options);return t}uglify.parser=e();uglify.uglify=r();s=uglify;return s}var i=dew();export default i;export{dew as __dew};

