///|
#derive(Eq, Debug)
pub(all) struct Json {
  raw : @json.Json
}

///|
fn hash_raw_json(j : @json.Json, hasher : Hasher) -> Unit {
  match j {
    Null => hasher.combine_int(0)
    True => hasher.combine_int(1)
    False => hasher.combine_int(2)
    String(s) => {
      hasher.combine_int(3)
      hasher.combine(s)
    }
    Number(d, ..) => {
      hasher.combine_int(4)
      hasher.combine(d)
    }
    Array(arr) => {
      hasher.combine_int(5)
      hasher.combine_int(arr.length())
      for item in arr {
        hash_raw_json(item, hasher)
      }
    }
    Object(obj) => {
      hasher.combine_int(6)
      hasher.combine_int(obj.length())
      obj.each(fn(k, v) {
        hasher.combine(k)
        hash_raw_json(v, hasher)
      })
    }
  }
}

///|
pub impl Hash for Json with hash_combine(self, hasher) {
  hash_raw_json(self.raw, hasher)
}

///|
pub impl @gprelude.GleamInspect for Json with gleam_inspect(self) {
  self.raw.stringify()
}

///|
fn json_to_dynamic(j : @json.Json) -> @gprelude.Dynamic {
  match j {
    Null => @gprelude.DynNull
    True => @gprelude.DynBool(true)
    False => @gprelude.DynBool(false)
    String(s) => @gprelude.DynString(s)
    Number(d, repr~) =>
      match repr {
        Some(r) =>
          if !(r.contains(".")) && !(r.contains("e")) && !(r.contains("E")) {
            try {
              @gprelude.DynInt(@str.parse_int64(r))
            } catch {
              _ => @gprelude.DynFloat(d)
            }
          } else {
            @gprelude.DynFloat(d)
          }
        None => @gprelude.DynFloat(d)
      }
    Array(arr) => {
      let items = arr.map(json_to_dynamic)
      @gprelude.DynList(@gprelude.GList::from_array(items[:]))
    }
    Object(obj) => {
      let m : Map[@gprelude.Dynamic, @gprelude.Dynamic] = Default::default()
      obj.each(fn(k, v) { m.set(@gprelude.DynString(k), json_to_dynamic(v)) })
      @gprelude.DynMap(m)
    }
  }
}

///|
pub fn decode_string(json_str : String) -> Result[@gprelude.Dynamic, (Int64, String)] {
  let parsed : @json.Json = try {
    @json.parse(json_str, preserve_number_repr=true)
  } catch {
    @json.InvalidEof => return Err((0L, ""))
    @json.InvalidChar(_, c) => return Err((1L, c.to_string()))
    @json.InvalidNumber(_, s) => return Err((2L, s))
    @json.InvalidIdentEscape(_) => return Err((2L, "escape"))
    @json.DuplicateKey(_, k) => return Err((2L, k))
    @json.DepthLimitExceeded => return Err((2L, "depth"))
  }
  Ok(json_to_dynamic(parsed))
}

///|
pub fn json_to_string(j : Json) -> String {
  j.raw.stringify()
}

///|
pub fn json_string(input : String) -> Json {
  { raw: @json.Json::string(input) }
}

///|
pub fn json_bool(input : Bool) -> Json {
  { raw: @json.Json::boolean(input) }
}

///|
pub fn json_int(input : Int64) -> Json {
  { raw: @json.Json::number(input.to_double(), repr=input.to_string()) }
}

///|
pub fn json_float(input : Double) -> Json {
  { raw: @json.Json::number(input) }
}

///|
pub fn json_null() -> Json {
  { raw: @json.Json::null() }
}

///|
pub fn json_object(entries : @gprelude.GList[(String, Json)]) -> Json {
  let m : Map[String, @json.Json] = Default::default()
  for cur = entries {
    match cur {
      @gprelude.Nil => break { raw: @json.Json::object(m) }
      @gprelude.Cons((k, v), rest) => {
        m.set(k, v.raw)
        continue rest
      }
    }
  }
}

///|
pub fn json_array(entries : @gprelude.GList[Json]) -> Json {
  { raw: @json.Json::array(entries.to_array().map(fn(j) { j.raw })) }
}
