import os
import time
import flag
import tipsy

fn print_and_exit(msg string, exit_code int) {
	if exit_code == 2 {
		eprintln(msg)
	} else {
		println(msg)
	}
	exit(exit_code)
}

fn on_signal(signum os.Signal) {
	// println('Bye bye via '+os.sigint_to_signal_name(signum))
	work_dir := [os.temp_dir(), '.tipsy'].join(os.path_separator)
	end_file := [work_dir, C.getpid().str() + '-signal'].join(os.path_separator)

	if !os.is_dir(work_dir) {
		os.mkdir_all(work_dir) or { panic(err) }
	}
	os.write_file(end_file, signum.str()) or { panic(err) }

	println('Caught signal ' + signum.str())
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('tipsy')
	fp.version('v0.1.0')
	fp.description('Tipsy the helpful context extractor')

	fp.skip_executable()

	tips_dir := fp.string('tips', 0, '', 'Path to tips')

	// additional_args :=
	fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	// TODO provide default? ~/.tipsy/tips or something
	if !os.is_dir(tips_dir) {
		panic('Tips directory "${tips_dir}" doesn\'t exist')
		// default_dir := os.home_dir()+(['.tipsy','tips'].join(os.path_separator))
		// println('Using default tips directory "$default_dir" as "$tips_dir" doesn\'t exist')
		// tips_dir = default_dir
	}

	work_dir := [os.temp_dir(), '.tipsy'].join(os.path_separator)

	end_file := [work_dir, C.getpid().str() + '-signal'].join(os.path_separator)
	if os.exists(end_file) {
		os.rm(end_file) or { panic(err) }
	}

	os.signal_opt(.int, on_signal)!

	// vfmt off
	config := tipsy.Config{
		// vfmt on
		dirs: {
			'tips': tips_dir
			'work': work_dir
		}
	}

	// vfmt off
	mut tips := tipsy.new(config)
	// vfmt on
	for {
		tips.update()

		if os.exists(end_file) {
			tips.end()
			os.rm(end_file) or { panic(err) }
			break
		}

		if tips.updated {
			tips.write()
		}
		time.sleep(500 * time.millisecond)
	}

	println('Bye bye')
}
