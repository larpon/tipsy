import os
import time
import flag

import tipsy

fn tmp_dir() string {
    mut path := os.getenv('TMPDIR')
    $if linux {
        if path == '' {
            path = '/tmp'
        }
    }
    $if mac {
        if path == '' {
            path = C.NSTemporaryDirectory() // TODO untested
        }
        if path == '' {
            path = '/tmp'
        }
    }
    $if windows {
        // TODO see Qt's implementation?
        // https://doc.qt.io/qt-5/qdir.html#tempPath
        // https://github.com/qt/qtbase/blob/e164d61ca8263fc4b46fdd916e1ea77c7dd2b735/src/corelib/io/qfilesystemengine_win.cpp#L1275
        path = os.getenv('TEMP')
        if path == '' { path = os.getenv('TMP') }
        if path == '' { path = 'C:/tmp' }
    }
    return path
}

fn print_and_exit( msg string, exit_code int ) {
    if exit_code == 2 { eprintln(msg) }
    else { println(msg) }
    exit(exit_code)
}

fn on_signal( signum int ) {
    //println('Bye bye via '+os.sigint_to_signal_name(signum))
    work_dir := [tmp_dir(), '.tipsy'].join(os.path_separator)
    end_file := [work_dir,C.getpid().str()+'-signal'].join(os.path_separator)

    if !os.dir_exists(work_dir) { os.mkdir_all(work_dir) }
    os.write_file(end_file,signum.str())

    println('Caught signal '+signum.str())
}

fn main() {

    mut fp := flag.new_flag_parser(os.args)
    fp.application('tipsy')
    fp.version('v0.1.0')
    fp.description('Tipsy the helpful context extractor')

    fp.skip_executable()

    tips_dir := fp.string('tips', '', 'Path to tips')

    //additional_args :=
    fp.finalize() or {
        eprintln(err)
        println(fp.usage())
        return
    }

    // TODO provide default? ~/.tipsy/tips or something
    if !os.dir_exists(tips_dir) {
        panic('Tips directory "$tips_dir" doesn\'t exist')
        //default_dir := os.home_dir()+(['.tipsy','tips'].join(os.path_separator))
        //println('Using default tips directory "$default_dir" as "$tips_dir" doesn\'t exist')
        //tips_dir = default_dir
    }

    work_dir := [tmp_dir(), '.tipsy'].join(os.path_separator)

    end_file := [work_dir,C.getpid().str()+'-signal'].join(os.path_separator)
    if os.file_exists(end_file) { os.rm(end_file) }

    os.signal(2, on_signal)

    config := tipsy.Config {
        dirs: {
            'tips': tips_dir,
            'work': work_dir
        }
    }

    mut tips := tipsy.new(config)
    for {
        tips.update()

        if os.file_exists(end_file) {
            tips.end()
            os.rm(end_file)
            break
        }

        if tips.updated { tips.write() }
        time.sleep_ms(500)
    }

    println('Bye bye')
}

