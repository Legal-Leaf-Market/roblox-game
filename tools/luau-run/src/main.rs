// luau-run tests/run.luau        runs a test file against src/shared
// luau-run --check FILE...        compiles each file without running it
use mlua::prelude::*;
use std::fs;

fn main() -> LuaResult<()> {
    let args: Vec<String> = std::env::args().collect();
    let lua = Lua::new();
    if args[1] == "--check" {
        let mut bad = 0;
        for f in &args[2..] {
            let src = fs::read_to_string(f).expect("read");
            if let Err(e) = lua.load(&src).set_name(f).into_function() {
                println!("{}", e);
                bad += 1;
            }
        }
        println!("{} files compiled, {} with errors", args.len() - 2 - bad, bad);
        std::process::exit(if bad > 0 { 1 } else { 0 });
    }
    let req = lua.create_function(|lua, name: String| {
        let path = format!("src/shared/{}.luau", name);
        let src = fs::read_to_string(&path).map_err(|e| LuaError::external(format!("{}: {}", path, e)))?;
        lua.load(&src).set_name(&path).eval::<LuaValue>()
    })?;
    lua.globals().set("requireShared", req)?;
    let test = fs::read_to_string(&args[1]).expect("test file");
    lua.load(&test).set_name(&args[1]).exec()
}
