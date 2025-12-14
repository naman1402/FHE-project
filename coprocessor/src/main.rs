mod config;

fn main() {
    let config = config::load_config().expect("Failed to load config");
    println!("Config loaded: {:?}", config);
}
