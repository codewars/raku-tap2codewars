use Test;
use lib 'lib';
use App::TAP2Codewars :testing;

my $dir = IO::Path.new($?FILE).dirname;

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

sub test-fixture($group, $name) {
    my $tap = IO::Path.new("fixtures/$group/$name.tap", :CWD($dir));
    my $out = IO::Path.new("fixtures/$group/$name.out", :CWD($dir));
    my $ios = IO::String.new;
    {
        my $*OUT = $ios;
        $tap.open.Supply
        ==> parser()
        ==> report();
    }
    is(~$ios, $out.open(:chomp(False)).lines.join, $group ~ "/" ~ $name);
}

subtest "raku", {
    test-fixture("raku", "pass-1");
    test-fixture("raku", "fail-1");
    test-fixture("raku", "subtest-pass-1");
    test-fixture("raku", "subtest-fail-1");
}

subtest "perl", {
    test-fixture("perl", "pass-1");
    test-fixture("perl", "fail-1");
    test-fixture("perl", "subtest-pass-1");
    test-fixture("perl", "subtest-fail-1");
}

done-testing;
# vim: ft=perl6 sw=4
