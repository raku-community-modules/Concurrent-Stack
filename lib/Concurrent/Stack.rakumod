class X::Concurrent::Stack::Empty is Exception {
    has Str $.operation is required;
    method message() {
        "Cannot $!operation from an empty concurrent stack"
    }
}

class Concurrent::Stack {
    my class Node {
        has $.value;
        has Node $.next;
    }

    has Node $!head;
    has atomicint $.elems;

    method push(Concurrent::Stack:D: $value) {
        cas $!head, -> $next {
            Node.new: :$value, :$next
        }
        $!elems⚛++;
        return $value;
    }

    method pop(Concurrent::Stack:D:) {
        my $taken;
        cas $!head, -> $current {
            fail X::Concurrent::Stack::Empty.new(:operation<pop>)
              without $current;
            $taken = $current.value;
            $current.next
        }
        $!elems⚛--;
        $taken
    }

    method peek(Concurrent::Stack:D:) {
        (my $current = ⚛$!head).defined
          ?? $current.value
          !! X::Concurrent::Stack::Empty.new(:operation<peek>).Failure
    }

    multi method Bool(Concurrent::Stack:D: --> Bool:D) {
        $!elems != 0
    }

    multi method Seq(Concurrent::Stack:D: --> Seq:D) {
        my Node $current = ⚛$!head;
        gather while $current {
            take $current.value;
            $current = $current.next;
        }
    }

    multi method list(Concurrent::Stack:D: --> List:D) {
        self.Seq.list
    }
}

=begin pod

=head1 NAME

Concurrent::Stack - A lock-free concurrent stack data structure

=head1 SYNOPSIS

=begin code :lang<raku>

use Concurrent::Stack;

my $stack = Concurrent::Stack.new;

for 'a'..'z' {
    $stack.push($_);
}

say $stack.elems;     # 26
say $stack.peek;      # z
say $stack.pop;       # z
say $stack.pop;       # y
say $stack.peek;      # x
$stack.push('k');
say $stack.peek;      # k
say $stack.elems;     # 25
say $stack.Seq;       # A Seq iterating a snapshot of the stack
say $stack.list;      # A lazy List with a snapshot of the stack

$stack.pop for ^25;
say $stack.elems;     # 0
my $x = $stack.peek;  # Failure with X::Concurrent::Stack::Empty 
my $y = $stack.pop;   # Failure with X::Concurrent::Stack::Empty

=end code

=head1 DESCRIPTION

Lock-free data structures may be safely used from multiple threads,
yet do not use locks in their implementation. They achieve this
through the use of atomic operations provided by the hardware.
Nothing can make contention between threads cheap - synchronization
at the CPU level is still synchronization - but lock free data
structures tend to scale better.

This lock-free stack data structure uses a linked list of immutable
nodes, the only mutable state being a head pointer to the node
representing the stack top and an element counter mintained through
atomic increment/decrement operations.  The element count updates
are not performed as part of the stack update, and so may lag the
actual state of the stack. However, since checking the number of
elements to decide whether to C<peek> or C<pop> is doomed in a
concurrent setting anyway (since another thread may C<pop> the
last value in the meantime), this is not problematic. The C<elems>
method primarily exists so that the number of elements can be queried
once the stack reaches some known stable point (for example, when a
bunch of working threads that C<push> to it are all known to have
completed their work).

=head1 METHODS

=head2 push(Any $value)

Pushes a value onto the stack. Returns the value that was pushed.

=head2 pop()

If the stack is not empty, removes the top value and returns it.
Otherwise, returns a C<Failure> containing an exception of typei
C<X::Concurrent::Stack::Empty>.

=head2 peek()

If the stack is not empty, returns the top value. Otherwise,
returns a `Failure` containing an exception of type
C<X::Concurrent::Stack::Empty>.

=head2 elems()

Returns the number of elements on the stack. This value can only
be relied upon when it is known that no threads are pushing/popping
from the stack at the point this method is called. B<Never> use the
result of C<elems> to decide whether to C<peek> or C<pop>, since
another thread may C<pop> in the meantime. Instead, check if C<peek>
or C<pop> return a C<Failure>.

head2 Bool()

Returns C<False> if the stack is empty and C<True> if the stack is
non-empty.  The result can only be relied upon when it is known that
no threads are pushing/popping from the stack at the point this
method is called. B<Never> use the result of C<Bool> to decide whether
to C<peek> or C<pop>, since another thread may C<pop> in the meantime.
Instead, check if C<peek> or C<pop> return a C<Failure>.

=head2 Seq()

Returns a C<Seq> that will iterate to a snapshot of the stack content,
starting from the stack top. The snapshot is made at the time this
method is called.

=head2 list()

Returns a C<List> that will lazily evaluate to a snapshot of the stack
content, starting from the stack top. The snapshot is made at the time
this method is called.

=head1 AUTHOR

Jonathan Worthington

=head1 COPYRIGHT AND LICENSE

Copyright 2018 - 2019 Raku Community

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
