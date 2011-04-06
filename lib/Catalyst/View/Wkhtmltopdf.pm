package Catalyst::View::Wkhtmltopdf;
use Moose;

extends 'Catalyst::View';

our $VERSION = '0.0002';
$VERSION = eval $VERSION;

use File::Temp;
use URI::Escape;

has 'stash_key' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'wk' }
);
has 'tmpdir' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { '/tmp' }
);
has 'command' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { '/usr/bin/wkhtmltopdf' }
);
has 'page_size' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'a4' }
);
has 'disposition' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'application/pdf' }
);
has 'filename' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { 'output.pdf' }
);
has 'allows' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] }
);

sub process {
    my($self, $c) = @_;

	my $wk = $c->stash->{$self->stash_key};
        
    my $html;
    if ( exists $wk->{template} ) {
        $html = $c->view('TT')->render($c, 'articles/export_pdf.tt');
    } else {
        $html = $wk->{html};
    }
    die 'Void-input' if !defined $html;

    # Usual page size A4, but labels would need a smaller one so we leave it
    my $page_size = '--page-size ' . ($wk->{page_size} // $self->page_size);
    
    # Custom page size will override the previous
    if ( defined $wk->{page_width} && defined $wk->{page_height} ) {
        $page_size = "--page-width $wk->{page_width} --page-height $wk->{page_height} ";
    }
   
    # Create a temporary file
    use File::Temp;
    my $htmlf = File::Temp->new(
        DIR     => $self->tmpdir,
        SUFFIX  => '.html',
        #UNLINK  => 0, # For testing
    );
    binmode $htmlf, ':utf8';
    my $htmlfn = $htmlf->filename; 
    my $pdffn = $htmlfn;
    $pdffn =~ s/\.html/.pdf/; 

    print $htmlf $html;
            
    # Build htmldoc command line
    my $hcmd = $self->command . ' ' . $page_size. ' ';
    $hcmd .= "--allow " . $self->tmpdir . " ";
    for my $allow (@{ $self->allows }) {
        $hcmd .= '--allow ' . $allow . ' ';
    }
    $hcmd .= "--margin-top $wk->{margin_top} " if exists $wk->{margin_top};
    $hcmd .= "--margin-left $wk->{margin_left} " if exists $wk->{margin_left};
    $hcmd .= "--margin-bottom $wk->{margin_bottom} " if exists $wk->{margin_bottom};
    $hcmd .= "--margin-right $wk->{margin_right} " if exists $wk->{margin_right};
    $hcmd .= " $htmlfn $pdffn";

    # Create the PDF file
    my $output = `$hcmd`;
    die "$! [likely can't find wkhtmltopdf command!]" if $output;
    
    # Read the output and return it
    my $pdffc = Path::Class::File->new($pdffn);
    my $pdfcontent = $pdffc->slurp();
    $pdffc->remove();
        
    my $disposition = $wk->{disposition} || $self->disposition;
    my $filename = uri_escape_utf8($wk->{filename} || $self->filename);
    $c->res->header(
        'Content-Disposition' => "$disposition; filename*=UTF-8''$filename",
        'Content-type'        => 'application/pdf',
    );
    $c->res->body( $pdfcontent );
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Catalyst::View::Wkhtmltopdf - Catalyst view to convert HTML (or TT) content to PDF using wkhtmltopdf

=head1 SYNOPSIS

    # lib/MyApp/View/Wkhtmltopdf.pm
    package MyApp::View::Wkhtmltopdf;
    use Moose;
    extends qw/Catalyst::View::Wkhtmltopdf/;
    __PACKAGE__->meta->make_immutable();
    1;
    
    # configure in lib/MyApp.pm
    MyApp->config({
      ...
      'View::Wkhtmltopdf' => {
          command   => '/usr/local/bin/wkhtmltopdf',
          tmpdir    => '/usr/tmp',
      },
    });
    
    sub ciao : Local {
        my($self, $c) = @_;
        
        # Pass some HTML...
        $c->stash->{wkhtmltopdf} = {
            html    => $web_page,
        };
        
        # ..or a TT template
        $c->stash->{wkhtmltopdf} = {
            template    => 'hello.tt',
            page_size   => 'a5',
        };

        # More parameters...
        $c->stash->{wkhtmltopdf} = {
            html        => $web_page,
            disposition => 'attachment',
            filename    => 'mydocument.pdf',
        };
        
        $c->forward('View::Wkhtmltopdf');
    }

=head1 DESCRIPTION

Catalyst::View::Wkhtmltopdf is a Catalyst View handler that converts
HTML data to PDF using wkhtmltopdf (which must be installed on your
system). It can also handle direct conversion of TT templates (via
L<Catalyst::View::TT>).

=head1 CONFIG VARIABLES

=over 4

=item stash_key

The stash key which contains data and optional runtime configuration
to pass to the view. Default is I<wkhtmltopdf>.

=item tmpdir

Name of URI parameter to specify JSON callback function name. Defaults
to C<callback>. Only effective when C<allow_callback> is turned on.

=item command

The full path and filename to the wkhtmltopdf command. Defaults to
I</usr/bin/wkhtmltopdf>.

=item allows

An arrayref of allowed paths where wkhtmltopdf can find images and
other linked content. The temporary directory is added by default.
See wkhtmltopdf documentation for more information.

=item disposition

The I<content-disposition> to set when sending the PDF file to the
client. Can be either I<inline> or (default) I<attachment>.

=item filename

The filename to send to the client. Default is I<output.pdf>.

=item page_size

Page size option (default: I<a4>).
See wkhtmltopdf documentation for more information.

=back

=head1 PARAMETERS

Parameters are passed fvia the stash:

    $c->stash->{wkhtmltopdf} = {
        html    => $web_page,
    };

You can pass the following configuration options here, which will
override the global configuration: I<disposition>, I<filename>,
I<page_size>.

Other options currently supported are:

=over 4

=item page-width, page-height

Width and height of the page, overrides I<page_size>.

=item margin-top, margin-right, margin-bottom, margin-left

Margins, specified as I<3mm>, I<0.7in>, ...

=back

Have a look at I<wkhtmltopdf> documentation for more information
regarding these options.

=head1 CHARACTER ENCODING

At present time this library just uses UTF-8, which means it should
work in most circumstances. Patches are welcome for support of
different character sets.

=head1 REQUIREMENTS

I<wkhtmltopdf> command should be available on your system.

=head1 TODO

More configuration options (all the ones which I<wkhtmltopdf>
supports, likely) should be added. Also, we'll wanto to allow
to override them all at runtime.

We might want to use pipes (L<IPC::Open2>) instead of relying
on temp files.

And yes... we need to write tests!

=head1 CONTRIBUTE

Project in on GitHub:

L<https://github.com/lordarthas/Catalyst-View-Wkhtmltopdf>

=head1 AUTHOR

Michele Beltrame E<lt>mb@italpro.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::View::TT>

L<http://code.google.com/p/wkhtmltopdf/>

=cut
