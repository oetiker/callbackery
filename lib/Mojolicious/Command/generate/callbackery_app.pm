package Mojolicious::Command::generate::callbackery_app;
use Mojo::Base 'Mojolicious::Command';
use File::Basename;
use Mojo::Util qw(class_to_file class_to_path slurp);
use POSIX qw(strftime);

our $VERSION = '0.3.0';

has description => 'Generate CallBackery web application directory structure.';
has usage => sub { shift->extract_usage };

sub run {
    my ($self, $class) = @_;
    $class ||= 'MyCallBackeryApp';

    # Prevent bad applications
    die <<EOF unless $class =~ /^[A-Z](?:\w|::)+$/;
Your application name has to be a well formed (CamelCase) Perl module name
like "MyApp".
EOF

    my $name = class_to_file $class;
    my $class_path = class_to_path $class;

    # Configure Main Dir
    my $file = {
        'configure.ac' => 'configure.ac',
        'bootstrap' => 'bootstrap',
        'PERL_MODULES' => 'PERL_MODULES',
        'VERSION' => 'VERSION',
        'README' => 'README',
        'AUTHORS' => 'AUTHORS',
        'LICENSE' => 'LICENSE',
        'COPYRIGHT' => 'COPYRIGHT',
        'CHANGES' => 'CHANGES',
        'Makefile.am' => 'Makefile.am',
        'etc/Makefile.am' => 'etc/Makefile.am',
        'etc/app.cfg' => 'etc/'.$name.'.cfg',
        'bin/script.pl' => 'bin/'.$name.'.pl',
        'bin/source-mode.sh' => 'bin/'.$name.'-source-mode.sh',
        'lib/App.pm' => 'lib/'.$class_path,
        'lib/Makefile.am' => 'lib/Makefile.am',
        'lib/App/GuiPlugin/Song.pm' => 'lib/'.$class.'/GuiPlugin/Song.pm',
        'lib/App/GuiPlugin/SongForm.pm' => 'lib/'.$class.'/GuiPlugin/SongForm.pm',
        'frontend/Makefile.am' => 'frontend/Makefile.am',
        'frontend/Manifest.json' => 'frontend/Manifest.json',
        'frontend/config.json' => 'frontend/config.json',
        'frontend/source/class/app/Application.js' => 'frontend/source/class/'.$name.'/Application.js',
        'frontend/source/class/app/__init__.js' => 'frontend/source/class/'.$name.'/__init__.js',
        'frontend/source/class/app/theme/Theme.js' => 'frontend/source/class/'.$name.'/theme/Theme.js',
        'frontend/source/index.html' => 'frontend/source/index.html',
        't/basic.t' => 't/basic.t',
    };

    my ($userName,$fullName) = (getpwuid $<)[0,6];
    $fullName =~ s/,.+//g;
    chomp(my $domain = `hostname -d`);
    my $email = $userName.'@'.$domain;

    if ( -r $ENV{HOME} . '/.gitconfig' ){
        my $in = slurp $ENV{HOME} . '/.gitconfig';
        $in =~ /name\s*=\s*(\S.+\S)/ and $fullName = $1;
        $in =~ /email\s*=\s*(\S+)/ and $email = $1;
    }

    for my $key (keys %$file){
        $self->render_to_rel_file($key, $name.'/'.$file->{$key}, {
            class => $class,
            name => $name,
            class_path => $class_path,
            year => (localtime time)[5]+1900,
            email => $email,
            fullName => $fullName,
            userName => $userName,
            date => strftime('%Y-%m-%d',localtime(time)),
        });
    }

    $self->chmod_rel_file("$name/bootstrap", 0755);
    $self->chmod_rel_file("$name/bin/".$name.".pl", 0755);
    $self->chmod_rel_file("$name/bin/".$name."-source-mode.sh", 0755);

    $self->create_rel_dir("$name/public");
    $self->create_rel_dir("$name/templates");
    $self->create_rel_dir("$name/frontend/source/resource/$name");
    $self->create_rel_dir("$name/frontend/source/translation");
    chdir $name;
    system "./bootstrap";
}

sub render_data {
  my ($self, $name) = (shift, shift);
    Mojo::Template->new->name("template $name")
    ->render(slurp(dirname($INC{'Mojolicious/Command/generate/callbackery_app.pm'}).'/callbackery_app/'.$name), @_);
}
1;
