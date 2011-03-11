package Catalyst::View::Wkhtmltopdf;
use Moose;

extends 'Catalyst::View';

our $VERSION = '0.00001';
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
    $hcmd .= "--margin-top $wk->{top_margin}mm " if exists $wk->{top_margin};
    $hcmd .= "--margin-left $wk->{left_margin}mm " if exists $wk->{left_margin};
    $hcmd .= "--margin-bottom $wk->{bottom_margin}mm " if exists $wk->{bottom_margin};
    $hcmd .= "--margin-right $wk->{right_margin}mm " if exists $wk->{right_margin};
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
