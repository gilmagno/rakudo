# This file implements the following set operators:
#   (|)     union (ASCII)
#   ∪       union

proto sub infix:<(|)>(|) is pure {*}
multi sub infix:<(|)>()               { set()  }
multi sub infix:<(|)>(QuantHash:D $a) { $a     } # Set/Bag/Mix
multi sub infix:<(|)>(Any $a)         { $a.Set } # also for Iterable/Map

multi sub infix:<(|)>(Setty:D $a, Setty:D $b) {
    nqp::if(
      (my \araw := $a.RAW-HASH) && nqp::elems(araw),
      nqp::if(                                    # first has elems
        (my \braw := $b.RAW-HASH) && nqp::elems(braw),
        nqp::stmts(                               # second has elems
          (my \elems := nqp::clone(araw)),
          (my \iter := nqp::iterator(braw)),
          nqp::while(                             # loop over keys of second
            iter,
            nqp::bindkey(                         # bind into clone of first
              elems,
              nqp::iterkey_s(nqp::shift(iter)),
              nqp::iterval(iter)
            )
          ),
          nqp::create($a.WHAT).SET-SELF(elems)    # make it a Set(Hash)
        ),
        $a                                        # no second, so first
      ),
      nqp::if(                                    # no first
        (my \raw := $b.RAW-HASH) && nqp::elems(raw),
        nqp::if(                                  # but second
          nqp::istype($a,Set), $b.Set, $b.SetHash
        ),
        $a                                        # both empty
      )
    )
}
multi sub infix:<(|)>(Setty:D $a, Mixy:D  $b) { $a.Mixy  (|) $b }
multi sub infix:<(|)>(Setty:D $a, Baggy:D $b) { $a.Baggy (|) $b }

multi sub infix:<(|)>(Mixy:D $a, Mixy:D $b) {
    nqp::if(
      (my \araw := $a.RAW-HASH) && nqp::elems(araw),
      nqp::if(                                    # first has elems
        (my \braw := $b.RAW-HASH) && nqp::elems(braw),
        nqp::stmts(                               # second has elems
          (my \elems := nqp::clone(araw)),
          (my \iter := nqp::iterator(braw)),
          nqp::while(                             # loop over keys of second
            iter,
            nqp::if(
              nqp::existskey(
                araw,
                (my \key := nqp::iterkey_s(nqp::shift(iter)))
              ),
              nqp::if(   # must use HLL < because values can be bignums
                nqp::getattr(
                  nqp::decont(nqp::atkey(araw,key)),Pair,'$!value')
                < nqp::getattr(                   # > hl
                    nqp::decont(nqp::atkey(braw,key)),Pair,'$!value'),
                nqp::bindkey(elems,key,nqp::atkey(braw,key))
              ),
              nqp::bindkey(elems,key,nqp::atkey(braw,key))
            )
          ),
          nqp::create($a.WHAT).SET-SELF(elems)   # make it a Mix(Hash)
        ),
        $a                                        # no second, so first
      ),
      nqp::if(                                    # no first
        (my \raw := $b.RAW-HASH) && nqp::elems(raw),
        nqp::if(                                  # but second
          nqp::istype($a,Mix), $b.Mix, $b.MixHash
        ),
        $a                                        # both empty
      )
    )
}

multi sub infix:<(|)>(Mixy:D $a, Baggy:D $b) { $a (|) $b.Mix }
multi sub infix:<(|)>(Mixy:D $a, Setty:D $b) { $a (|) $b.Mix }

multi sub infix:<(|)>(Baggy:D $a, Mixy:D $b) { $a.Mixy (|) $b }
multi sub infix:<(|)>(Baggy:D $a, Baggy:D $b) {
    nqp::if(
      (my \araw := $a.RAW-HASH) && nqp::elems(araw),
      nqp::if(                                    # first has elems
        (my \braw := $b.RAW-HASH) && nqp::elems(braw),
        nqp::stmts(                               # second has elems
          (my \elems := nqp::clone(araw)),
          (my \iter := nqp::iterator(braw)),
          nqp::while(                             # loop over keys of second
            iter,
            nqp::if(
              nqp::existskey(
                araw,
                (my \key := nqp::iterkey_s(nqp::shift(iter)))
              ),
              nqp::if(
                nqp::islt_i(
                  nqp::getattr(
                    nqp::decont(nqp::atkey(araw,key)),Pair,'$!value'),
                  nqp::getattr(
                    nqp::decont(nqp::atkey(braw,key)),Pair,'$!value')
                ),
                nqp::bindkey(elems,key,nqp::atkey(braw,key))
              ),
              nqp::bindkey(elems,key,nqp::atkey(braw,key))
            )
          ),
          nqp::create($a.WHAT).SET-SELF(elems)   # make it a Bag
        ),
        $a                                        # no second, so first
      ),
      nqp::if(                                    # no first
        (my \raw := $b.RAW-HASH) && nqp::elems(raw),
        nqp::if(                                  # but second
          nqp::istype($a,Bag), $b.Bag, $b.BagHash
        ),
        $a                                        # both empty
      )
    )
}
multi sub infix:<(|)>(Baggy:D $a, Setty:D $b) { $a (|) $b.Bag }

multi sub infix:<(|)>(Map:D $a, Map:D $b) {
    nqp::create(Set).SET-SELF(
      Rakudo::QuantHash.ADD-MAP-TO-SET(
        Rakudo::QuantHash.COERCE-MAP-TO-SET($a),
        $b
      )
    )
}

multi sub infix:<(|)>(Iterable:D $a, Iterable:D $b) {
    nqp::if(
      (my $aiterator := $a.flat.iterator).is-lazy
        || (my $biterator := $b.flat.iterator).is-lazy,
      Failure.new(X::Cannot::Lazy.new(:action<union>,:what<set>)),
      nqp::create(Set).SET-SELF(
        Rakudo::QuantHash.ADD-PAIRS-TO-SET(
          Rakudo::QuantHash.ADD-PAIRS-TO-SET(
            nqp::create(Rakudo::Internals::IterationSet),
            $aiterator,
            Mu
          ),
          $biterator,
          Mu
        )
      )
    )
}

multi sub infix:<(|)>(Failure:D $a, Any $b) { $a.throw }
multi sub infix:<(|)>(Any $a, Failure:D $b) { $b.throw }
multi sub infix:<(|)>(Any $a, Any $b) {
    nqp::if(
      nqp::isconcrete($a),
      nqp::if(
        nqp::istype($a,Mixy),
        infix:<(|)>($a, $b.Mix),
        nqp::if(
          nqp::istype($a,Baggy),
          infix:<(|)>($a, $b.Bag),
          nqp::if(
            nqp::istype($a,Setty),
            infix:<(|)>($a, $b.Set),
            nqp::if(
              nqp::isconcrete($b),
              nqp::if(
                nqp::istype($b,Mixy),
                infix:<(|)>($a.Mix, $b),
                nqp::if(
                  nqp::istype($b,Baggy),
                  infix:<(|)>($a.Bag, $b),
                  infix:<(|)>($a.Set, $b.Set)
                )
              ),
              infix:<(|)>($a, $b.Set)
            )
          )
        )
      ),
      infix:<(|)>($a.Set, $b)
    )
}

multi sub infix:<(|)>(**@p) {
    my $result = @p.shift;
    $result = $result (|) @p.shift while @p;
    $result
}

# U+222A UNION
my constant &infix:<∪> := &infix:<(|)>;

# vim: ft=perl6 expandtab sw=4
