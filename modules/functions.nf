// Shared helper functions.
//
// Under the strict syntax parser (default from Nextflow 26.04) values supplied on
// the command line are NOT converted to booleans or numbers, so "--kraken false"
// arrives as the String "false", which is truthy. Every boolean parameter must
// therefore be read through as_bool().

def as_bool(value) {
    if( value == null )
        return false
    if( value instanceof Boolean )
        return value
    def text = value.toString().trim().toLowerCase()
    if( ['true', 'y', 'yes', '1'].contains(text) )
        return true
    if( ['false', 'n', 'no', '0', ''].contains(text) )
        return false
    error "Expected a true/false value but got '${value}'. Use true or false."
}

def check_file(value, name) {
    if( !value )
        error "Missing required parameter --${name}"
    def target = file(value)
    if( !target.exists() )
        error "--${name}: no such file or directory: ${value}"
    return target
}

def check_dir(value, name) {
    if( !value )
        error "Missing required parameter --${name}"
    def target = file(value)
    if( !target.exists() )
        error "--${name}: no such file or directory: ${value}"
    return target
}
