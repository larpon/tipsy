import os
import flag
import time

// TODO unify with the one used in tipsy.v
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

fn main() {

    mut warning_display := false

    mut fp := flag.new_flag_parser(os.args)
    fp.application('syncs')
    fp.version('v0.1.0')
    fp.description('Syncs a simple tipsy context console client')

    fp.skip_executable()

    pid := fp.int('pid', 0, 'Read context from <pid> tipsy process')

    tips_dir := fp.string('tips', '', 'Path to tips')
    if !os.dir_exists(tips_dir) {
        warning_display = true
        eprintln('Tips directory "$tips_dir" doesn\'t exist')
    }

    //additional_args :=
    fp.finalize() or {
        eprintln(err)
        println(fp.usage())
        return
    }

    tipsy_work := [tmp_dir(), '.tipsy'].join(os.path_separator)

    if warning_display {
        time.sleep_ms(2000)
    }

    mut tpid := 0
    mut app := ''
    for {
        running := os.ls(tipsy_work) or { panic(err) }

        if running.len <= 0 {
            time.sleep_ms(2000)
            continue
        }

        if tpid == 0 && running[0].int() != tpid {
            if pid > 0 {
                for spid in running {
                    if spid.int() == pid {
                        tpid = pid
                    }
                }
            }
            if tpid == 0 { tpid = running[0].int() }
            println('Using tipsy instance '+tpid.str())
        }

        context_dir := [tipsy_work,tpid.str(),'context'].join(os.path_separator)
        tapp := os.read_file([context_dir,'app'].join(os.path_separator)) or { panic(err) }
        if tapp != app {
            app = tapp

            os.clear()

            app_file := [tips_dir,'$app'].join(os.path_separator)
            if(os.file_exists(app_file)) {
                tip := os.read_file(app_file) or { panic(err) }
                println(tip)
            } else {
                println('No tip for '+app)
            }
        }

        time.sleep_ms(1000)
    }

}
