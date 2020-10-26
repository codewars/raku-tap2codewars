use v6;
unit module App::TAP2Codewars;

use TAP;

sub MAIN() is export(:MAIN) {
    $*IN.Supply
    ==> parser()
    ==> report();
}

# Output the test result in Codewars format based on the entries from the TAP parser.
sub report(Supply $entries) is export(:testing) {
    react {
        enum State <Normal AfterTestFailure AfterSubTestFailure>;
        my State $state = Normal;
        # For buffering failure diagnostics that comes after test result.
        my Str @buffer;
        # For buffering logs (unknown lines) that always comes before a test or test group.
        my Str @logs;
        # Flag to output log as error. Used when the type check failed and the test didn't even start.
        my Bool $error-log = False;

        sub output-buffered() {
            if ?@buffer {
                if $state == AfterTestFailure {
                    # `indent(*)` outdents to the margin (removes common white space)
                    say "\n<FAILED::>Test Failed<:LF:>{@buffer.join.indent(*).trim-trailing.subst("\n", "<:LF:>", :g)}";
                    say "\n<COMPLETEDIN::>";
                } else {
                    say "\n{@buffer.join.trim-trailing.subst("\n", "<:LF:>", :g)}";
                }
                @buffer = ();
            }
            $state = Normal;
        }

        sub output-logs() {
            if ?@logs {
                if $error-log {
                    say "\n<ERROR::>{@logs.join("\n").trim-trailing.subst("\n", "<:LF:>", :g)}";
                } else {
                    .say for @logs;
                }
                @logs = ();
                $error-log = False;
            }
        }

        sub handle-entry(TAP::Entry $entry) {
            given $entry {
                when TAP::Sub-Test { handle-sub-test($entry) }
                when TAP::Test { handle-test($entry) }
                when TAP::Comment { handle-comment($entry) }
                when TAP::YAML { handle-yaml($entry) }
                when TAP::Version {}
                when TAP::Plan { handle-plan($entry) }
                default {
                    if $entry.raw ~~ /:s ^^Type check failed .+$$/ {
                        $error-log = True;
                    }
                    @logs.append: $entry.raw;
                }
            }
        }

        sub handle-plan(TAP::Plan $) {
            output-buffered();
        }

        sub handle-test(TAP::Test $test) {
            output-buffered();
            my $name = $test.description || "test {$test.number}";
            say "\n<IT::>{$name}";
            output-logs();

            if $test.ok {
                say "\n<PASSED::>Test Passed";
                say "\n<COMPLETEDIN::>";
            } else {
                $state = AfterTestFailure;
            }
        }

        sub handle-sub-test(TAP::Sub-Test $sub-test) {
            output-buffered();
            my $name = $sub-test.description || "tests {$sub-test.number}";
            say "\n<DESCRIBE::>{$name}";
            output-logs();

            for $sub-test.entries -> $entry {
                handle-entry($entry);
            }

            say "\n<COMPLETEDIN::>";

            $state = AfterSubTestFailure unless $sub-test.ok;
        }

        sub handle-yaml(TAP::YAML $yaml) {
            @buffer.append: $yaml.serialized ~ "\n";
        }

        sub handle-comment(TAP::Comment $comment) {
            # Ignore diagnostics after subtest failure.
            # We already have the subtest name.
            return if $state == AfterSubTestFailure;

            # Not using `.comment` to avoid losing the leading spaces.
            my $content = $comment.raw.subst("# ");
            # Skip some redundant comments
            return if $state == Normal && $content ~~ /:s ^^Subtest: .+$$/;
            return if $content ~~ /:s ^^You failed \d+ tests? of \d+$$/;
            return if $content ~~ /:s ^^Looks like you failed \d+ tests? of \d+\.$$/;
            return if $content ~~ /:s ^^\s*Failed test at .+ line \d+\.?$$/;
            return if $content ~~ /:s ^^\s*Failed test \'.+$$/;
            return if $content ~~ /:s ^^\s*at .+ line \d+\.?$$/;

            @buffer.append: $content ~ "\n";
        }

        whenever $entries {
            handle-entry($_);
            LAST {
                # Output anything left in case of incomplete input.
                output-buffered();
                output-logs();
            }
        }
    }
}

# Rest of this file (Grammar and parser) were copied and modified from [TAP].
# [TAP]: https://github.com/Raku/tap-harness6/blob/971df1607ec6e5e1fbf5483272e42f2310b78b16/lib/TAP.pm#L170-L358
grammar Grammar {
    regex TOP {
        ^ [ <plan> | <test> | <bailout> | <version> | <comment> || <unknown> ] $
    }
    token sp { <[\s] - [\n]> }
    token num { <[0..9]>+ }
    token plan {
        '1..' <count=.num> <.sp>* [
            '#' <.sp>* $<directive>=[:i 'SKIP'] \S*
            [ <.sp>+ $<explanation>=[\N*] ]?
        ]?
    }
    regex description {
        [ '\\\\' || '\#' || <-[\n#]> ]+ <!after <sp>+>
    }
    token test {
        $<nok>=['not '?] 'ok' [ <.sp> <num> ]? ' -'?
            [ <.sp>* <description> ]?
            [
                <.sp>* '#' <.sp>* $<directive>=[:i [ 'SKIP' \S* | 'TODO'] ]
                [ <.sp>+ $<explanation>=[\N*] ]?
            ]?
            <.sp>*
    }
    token bailout {
        'Bail out!' [ <.sp> $<explanation>=[\N*] ]?
    }
    token version {
        :i 'TAP version ' <version=.num>
    }
    token comment {
        '#' <.sp>* $<comment>=[\N*]
    }
    token yaml(Int $indent = 0) {
        '  ---' \n
        [ ^^ <.indent($indent)> '  ' $<yaml-line>=[<!before '...'> \N* \n] ]*
        <.indent($indent)> '  ...'
    }
    token sub-entry(Int $indent) {
        <plan> | <test> | <comment> | <yaml($indent)> | <sub-test($indent)> || <!before <.sp> > <unknown>
    }
    token indent(Int $indent) {
        '    ' ** { $indent }
    }
    token sub-test(Int $indent = 0) {
        '    '
        [ <sub-entry($indent + 1)> \n ]+ % [ <.indent($indent+1)> ]
        <.indent($indent)> <test>
    }
    token unknown {
        \N*
    }

    class Actions {
        method TOP($/) {
            make $/.values[0].made;
        }
        method plan($/) {
            my %args = :raw(~$/), :tests(+$<count>);
            if $<directive> {
                %args<skip-all explanation> = True, ~$<explanation>;
            }
            make TAP::Plan.new(|%args);
        }
        method description($m) {
            $m.make: ~$m.subst(/\\('#'|'\\')/, { $_[0] }, :g)
        }
        method !make_test($/) {
            my %args = (:ok($<nok> eq ''));
            %args<number> = $<num> ?? +$<num> !! Int;
            %args<description> = $<description>.made if $<description>;
            %args<directive> = $<directive> ?? TAP::Directive::{~$<directive>.substr(0,4).tclc} !! TAP::No-Directive;
            %args<explanation> = ~$<explanation> if $<explanation>;
            %args;
        }
        method test($/) {
            make TAP::Test.new(:raw(~$/), |self!make_test($/));
        }
        method bailout($/) {
            make TAP::Bailout.new(:raw(~$/), :explanation($<explanation> ?? ~$<explanation> !! Str));
        }
        method version($/) {
            make TAP::Version.new(:raw(~$/), :version(+$<version>));
        }
        method comment($/) {
            make TAP::Comment.new(:raw(~$/), :comment(~$<comment>));
        }
        method yaml($/) {
            my $serialized = $<yaml-line>.join('');
            my $deserialized = try (require YAMLish) ?? YAMLish::load-yaml("---\n$serialized...") !! Any;
            make TAP::YAML.new(:raw(~$/), :$serialized, :$deserialized);
        }
        method sub-entry($/) {
            make $/.values[0].made;
        }
        method sub-test($/) {
            make TAP::Sub-Test.new(:raw(~$/), :entries(@<sub-entry>».made), |self!make_test($<test>));
        }
        method unknown($/) {
            make TAP::Unknown.new(:raw(~$/));
        }
    }

    method parse(|c) {
        my $*tap-indent = 0;
        nextwith(:actions(Actions), |c);
    }
    method subparse(|c) {
        my $*tap-indent = 0;
        nextwith(:actions(Actions), |c);
    }
}

sub parser(Supply $input --> Supply) is export(:testing) {
    supply {
        enum Mode <Normal SubTest Yaml >;
        my Mode $mode = Normal;
        my Str @buffer;
        sub set-state(Mode $new, Str $line) {
            $mode = $new;
            @buffer = $line;
        }
        sub emit-unknown(*@more) {
            @buffer.append: @more;
            for @buffer -> $raw {
                emit TAP::Unknown.new(:$raw);
            }
            @buffer = ();
            $mode = Normal;
        }
        sub emit-reset(Match $entry) {
            emit $entry.made;
            @buffer = ();
            $mode = Normal;
        }

        my token indented { ^ '    ' }

        my $grammar = Grammar.new;

        whenever $input.lines -> $line {
            if $mode == Normal {
                if $line ~~ / ^ '  ---' / {
                    set-state(Yaml, $line);
                }
                elsif $line ~~ &indented {
                    set-state(SubTest, $line);
                }
                else {
                    emit-reset $grammar.parse($line);
                }
            }
            elsif $mode == SubTest {
                if $line ~~ &indented {
                    @buffer.push: $line;
                }
                elsif $grammar.parse($line, :rule('test')) -> $test {
                    my $raw = (|@buffer, $line).join("\n");
                    if $grammar.parse($raw, :rule('sub-test')) -> $subtest {
                        emit-reset $subtest;
                    }
                    else {
                        emit-unknown;
                        emit-reset $test;
                    }
                }
                else {
                    # HACK Emit `Unknown` immediately when inside SubTest
                    #      to prevent parsing sub-test from failing.
                    #      This will result in all logs appearing before the test group
                    #      and it's not ideal, but it's better than unusable output.
                    emit TAP::Unknown.new(:raw($line));
                    # emit-unknown $line;
                }
            }
            elsif $mode == Yaml {
                if $line ~~ / ^ '  '  $<content>=[\N*] $ / {
                    @buffer.push: $line;
                    if $<content> eq '...' {
                        my $raw = @buffer.join("\n");
                        if $grammar.parse($raw, :rule('yaml')) -> $yaml {
                            emit-reset $yaml;
                        }
                        else {
                            emit-unknown;
                        }
                    }
                }
                else {
                    emit-unknown $line;
                }
            }
        }
        LEAVE { emit-unknown }
    }
}

# vim: ft=perl6 sw=4
