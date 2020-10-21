use Test;
use lib 'lib';
use App::TAP2Codewars :testing;

class IO::String is IO::Handle {
    has @.contents;
    method print(*@what) {
        @.contents.push: @what.join('');
    }
    method print-nl {
        self.print($.nl-out);
    }
    method Str { @.contents.join }
}

sub test-fixtures() {
    my $dir = IO::Path.new($?FILE).dirname;
    my $fixtures = IO::Path.new("fixtures", :CWD($dir));
    for $fixtures.dir() -> $lang {
        if $lang.d {
            my $group = $lang.basename;
            subtest $group, {
                for $lang.dir(test =>  / '.' tap $/) -> $tap {
                    my $name = $tap.basename;
                    my $out = $tap.extension: "out";
                    my $ios = IO::String.new;
                    {
                        my $*OUT = $ios;
                        $tap.open.Supply
                        ==> parser()
                        ==> report();
                    }
                    is(~$ios, $out.open(:chomp(False)).lines.join, "$group/$name");
                }
            }
        }
    }
}

test-fixtures();

done-testing;
# vim: ft=perl6 sw=4
