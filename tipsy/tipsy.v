module tipsy

import os

struct Window {
pub:
	id    int
	pid   int
	title string
	valid bool
}

pub fn (w Window) eq(o Window) bool {
	return w.id == o.id && w.pid == o.pid && w.title == o.title && w.valid == o.valid
}

struct Context {
pub:
	window Window
	valid  bool
	app    string
	parent string
	alias  string
	url    string
	tags   []string
	config Config
}

pub fn (c Context) eq(o Context) bool {
	return c.window.eq(o.window) && c.valid == c.valid && c.app == o.app && c.parent == o.parent
		&& c.tags.str() == o.tags.str()
}

pub struct Config {
	dirs map[string]string
}

struct Tipsy {
	pid    int // Tipsy's own pid
	config Config

	apps    []string // list of process names that have tips to show
	parents []string // list of processes that we should capture for child processes
	aliases map[string]string // map of process names that maps to another name
pub mut:
	context         Context
	previous_window Window // for detecting changes

	updated bool // set if a call to ::update actually has anything new
}

pub fn new(config Config) Tipsy {
	$if !linux {
		panic('Currently only linux is supported')
	}

	expect_tool('xdotool')

	data_path := os.real_path(config.dirs['tips'])
	if !os.is_dir(data_path) {
		panic('Tipsy: "$data_path" is not a directory')
	}

	pid := os.getpid()

	println('Tipsy (' + pid.str() + ') in "$data_path"')

	mut apps := []string{}
	mut file := ''
	// Look for accepted process names i.e. "tips" for each processname
	files := os.ls(data_path) or { panic(err) }
	for e in files {
		file = data_path + os.path_separator + e
		if os.is_file(file) {
			// println('Tipsy ('+pid.str()+') adding tip for "$e"')
			apps << e
		}
	}

	parents_file := os.join_path(data_path, 'parents.tipsy')
	mut parents := []string{}
	if os.is_file(parents_file) {
		parents = os.read_lines(parents_file) or { []string{} }
		// println('Tipsy ('+pid.str()+') adding parents $parents')
		didx := apps.index('parents.tipsy')
		if didx > -1 {
			apps.delete(didx)
		}
	}

	aliases_file := os.join_path(data_path, 'aliases.tipsy')
	mut aliases := map[string]string{}
	if os.is_file(parents_file) {
		lines := os.read_lines(aliases_file) or { []string{} }
		for line in lines {
			if line == '' || !line.contains(' ') {
				continue
			}
			sp := line.split(' ')
			if sp.len > 1 && sp[0] != '' {
				aliases[sp[0]] = sp[1]
			}
		}
		// println('Tipsy ('+pid.str()+') added aliases $aliases')
		didx := apps.index('aliases.tipsy')
		if didx > -1 {
			apps.delete(didx)
		}
	}

	return Tipsy{
		pid: pid
		config: config
		updated: false
		apps: apps
		parents: parents
		aliases: aliases
	}
}

fn rm_file(path string) {
	if os.is_file(path) {
		os.rm(path) or { panic(err) }
	}
}

pub fn (t Tipsy) end() {
	pid_dir := os.join_path(t.config.dirs['work'], t.pid.str())
	println('Cleaning up ' + pid_dir)
	if os.is_dir(pid_dir) {
		os.walk(pid_dir, rm_file)
		os.rmdir(os.join_path(pid_dir, 'context')) or { panic(err) }
		os.rmdir(pid_dir) or { panic(err) }
	}
}

pub fn (mut t Tipsy) update() Context {
	// println(t.config)
	t.updated = false

	window_name := run('xdotool getwindowfocus getwindowname')

	valid := window_name != ''

	mut active_window_id := 0
	if valid {
		active_window_id = run('xdotool getactivewindow').int()
	}

	// TODO run these two in parallel and wait for them when available in v
	mut window_pid := 0
	if valid {
		window_pid = run('xdotool getwindowpid "$active_window_id"').int()
	}

	win := Window{
		id: active_window_id
		valid: valid
		pid: window_pid
		title: window_name
	}

	t.context = Context{
		window: win
		valid: win.valid
		config: t.config
	}

	if !win.eq(t.previous_window) {
		if valid {
			t.context = t.extract(win)
		}
		t.previous_window = win
		t.updated = true
	}

	return t.context
}

pub fn (t Tipsy) context_dir() string {
	return os.join_path(t.config.dirs['work'], t.pid.str(), 'context')
}

pub fn (t Tipsy) write_attr(attr string, data string) {
	out_dir := t.context_dir()
	if !os.is_dir(out_dir) {
		os.mkdir_all(out_dir) or { panic(err) }
	}
	os.write_file(os.join_path(out_dir, attr), data) or { panic(err) }
}

pub fn (t Tipsy) write_attr_string_array(attr string, data []string) {
	out_file := os.join_path(t.context_dir(), 'tags')

	mut f := os.create(out_file) or { panic(err) }
	for tag in t.context.tags {
		f.writeln(tag) or { panic(err) }
	}
	f.close()
}

pub fn (t Tipsy) write() {
	ctx := t.context

	// TODO include in some DEBUG setup?
	// println('Writing context')
	// println(ctx)

	t.write_attr('app', ctx.app)
	t.write_attr('parent', ctx.parent)
	t.write_attr('alias', ctx.alias)

	t.write_attr_string_array('tags', ctx.tags)
	t.write_attr('url', ctx.url)
	t.write_attr('valid', ctx.valid.str())
	t.write_attr('pid', ctx.window.pid.str())
	t.write_attr('window.title', ctx.window.title)
}

fn (t Tipsy) extract(win Window) Context {
	if !win.valid {
		return Context{
			window: win
			valid: win.valid
			config: t.config
		}
	}

	mut app := ''
	mut tags := []string{}

	title := win.title
	title_lowercase := title.to_lower()

	mut lookup := ''

	// Can be tested with screen locker / saver
	if win.pid <= 0 { // Resolve from window title
		title_split := title.split(' ')

		// delimiter := ' '
		first_word := title_split.first()
		last_word := title_split.last()

		if first_word.to_lower() in t.apps {
			lookup = first_word
		} else if last_word.to_lower() in t.apps {
			lookup = last_word
		} else {
			/*
			TODO deeper parsing of title
            if [[ $_w_str =~ .*—.* ]]; then
                _delimiter="—"
            elif [[ $_w_str =~ .*-.* ]]; then
                _delimiter="-"
            fi

            case "$_w_str" in *"$_delimiter"*) _delimiter="$_delimiter" ;; *) _delimiter="" ;; esac

            _lookup="$_w_str"

            if [ "$_delimiter" != "" ]; then
                _lookup="${_w_str##*$_delimiter }"
            else
                _lookup="$_first_word"
            fi
			*/
		}
		lookup = lookup.to_lower()
		tags << 'unprecise-match'
	} else {
		$if linux {
			lookup = run('cat /proc/' + win.pid.str() + '/comm')
		}
	}

	app = lookup

	// mut known := false
	mut parent := ''
	mut alias := ''
	mut url := ''

	if app != '' {
		has_parent := app in t.parents
		alias = if app in t.aliases.keys() { t.aliases[app] } else { '' }

		if alias != '' {
			tags << 'has-alias'
		}
		if has_parent {
			// println('$app is parent')
			parent = app

			if app == 'konsole' {
				lookup = run('echo "$title_lowercase" | sed -r \'s/.* : (.*) — konsole/\\1/g\'') // TODO replace by V regex solution when available

				url = run('echo "$title_lowercase" | sed -r \'s/(.*) : .* — konsole/\\1/g\'') // TODO replace by V regex solution when available

				// echo -e "has-parent\nparent-$_parent" >> "$_tags_file.tmp"
				// echo "$_path" > "$_dir_file"
			} else if app == 'AppRun' {
				lookup = run('echo "$title_lowercase" | sed -r \'s/.*— (.*)/\\1/g\'')

				// println('HEY '+lookup+' : '+rt)
				//_lookup=$(sed -r 's/.*— (.*)/\1/g' <<< "$_w_str_lower")
				// case "${_apps[@]}" in *"$_lookup"*) _app="$_lookup" ;; esac

				// echo -e "has-parent\nparent-$_parent" >> "$_tags_file.tmp"
			}

			if lookup in t.apps {
				// println('$lookup in apps')
				app = lookup
			}

			tags << 'has-parent'
		}
		// known = true
		tags << 'known'
	} else {
		app = lookup
		if win.pid > 0 {
			app = run('cat /proc/' + win.pid.str() + '/comm')
		}
		tags << 'unknown'
	}

	// println(lookup+' in '+t.apps.str())
	context_file := os.real_path(os.join_path(t.config.dirs['tips'], app))
	if app in t.apps {
		if os.exists(context_file) {
			// content := os.read_file(context_file) or { panic('Couldn\'t read '+context_file) }
			tags << 'has-tip'
			// println(content)
		}
	}

	tags << app
	tags << 'process-name-' + app

	tags.sort()

	return Context{
		window: win
		valid: win.valid
		app: app
		parent: parent
		alias: alias
		url: url
		tags: tags
		config: t.config
	}
}

// See https://github.com/vlang/v/blob/master/tools/performance_compare.v
fn run(cmd string) string {
	x := os.execute(cmd)
	if x.exit_code == 0 {
		return x.output.trim_right('\n')
	}
	return ''
}

fn command_exits_with_zero_status(cmd string) bool {
	x := os.execute(cmd)
	if x.exit_code == 0 {
		return true
	}
	return false
}

// TODO make variadic : toolcmd ...string , toolcmd[0]?
// See https://github.com/vlang/v/blob/master/compiler/tests/fn_variadic_test.v
fn expect_tool(toolcmd string) {
	if command_exits_with_zero_status('type $toolcmd') {
		return
	}
	eprintln('Missing tool: $toolcmd')
	eprintln('Please try again after you install it.')
	exit(1)
}

/*
fn expect_tool(tools ...string) {
    for tool in tools {
        if !command_exits_with_zero_status( 'type $tool' ) {
            eprintln('Missing tool: $tool')
            eprintln('Please try again after you install it.')
            exit(1)
        }
    }
}
*/
