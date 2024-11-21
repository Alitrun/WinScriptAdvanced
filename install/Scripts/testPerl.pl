#testing Perl script - reading first line of txt file
#Plugin adds path to a script with a one slash (not \\), e.g: $filename = "d:\qwe.txt"; 
our ($content);

open( my $file, $filename);
$content = <$file>;
close $file;