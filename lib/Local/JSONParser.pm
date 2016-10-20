package Local::JSONParser;
use strict;
use warnings;
use base qw(Exporter);
our @EXPORT_OK = qw( parse_json );
our @EXPORT = qw( parse_json );

my $reg= qr{
  (?&VALUE) (?{$_ = $^R->[1]; })     # в переменной $^R находится результат последнего выполненого блока (?{code})
  (?(DEFINE)                         # объявления подшаблонов, условная конструкция которая всегда ложная. в нее мы можем перейти только вызвав именованный подшаблон , который находится в ней путем (?&Name)
    (?<VALUE>
      \s*
      (
          (?&STRING)
        |
          (?&NUMBER)
        |
          (?&OBJECT)
        |
          (?&ARRAY)
        |
          true  (?{ [$^R, 1] })
        |
          false (?{ [$^R, 0] })
        |
          null  (?{ [$^R, undef] })
      )
      \s*
    )
    (?<STRING>                      # сюда мы перешли из  (?&STRING)
      \s*                           # не включаю в строку пробелы которые могут быть до ковычек, но учитываю что они могут быть
      "(                            #начало сохраняющей группы,не включаю в строку ковычки, поэтому они вне сохр группы
        (?:                         
            (?:\\ ["] )* (?:[^"])*  # подшаблон который будет есть все что между " " это описывается (?:[^"])* т е все кроме ковычек ,
                                    # кроме случая когда ковычка экранирована
                                    # поэтому и добавляю  (?:\\ ["] )* на случай а вдруг она есть
        )*                          # в конце несохр группы звездочка потому что строка может быть пустая
      )"                            # конец сохраняющей группы
      \s*                           # не включаю в строку пробелы которые могут быть до ковычек, но учитываю что они могут быть
      #(?{ [$^R, eval $^N] })
       (?{  my $ref = $^R;          
            my $str = $^N;
            $str =~ s/(\\["bfnrt])/$1 eq "\\t" ? "\t" : $1 eq "\\n"  ? "\n":$1 eq "\\b"  ? "\b":$1 eq "\\f"  ? "\f":$1 eq "\\r"  ? "\r":$1 eq "\\\""  ? "\"":""/eg;
            $ref = [$ref,$str];
            return $ref;
        }) 
    )
    (?<NUMBER>
      \s*
      ( 
        (?: -?(?=0\.\d+)0 | -? [1-9]\d* ) (?: \. \d+ )? (?: [eE] [-+]? \d+ )?
        )
      (?{  [$^R, 0+$^N] })
      \s*
    )
    (?<OBJECT>
      (?{ [$^R, {}] })
      \{\s*
        (?:
          (?&ELEM)       (?{ [$^R->[0][0], {$^R->[1] => $^R->[2]}] })
            (?:,(?&ELEM)      (?{ [$^R->[0][0], {%{$^R->[0][1]}, $^R->[1] => $^R->[2]}] }) 
          )*
          |
          (?:[ ]*) (?{return $^R})
          
        )?
        
      \}    
    )
        (?<ELEM>
          (?&STRING) :  (?&VALUE)                                                            
          (?{ [$^R->[0][0], $^R->[0][1], $^R->[1]]})
        )
    (?<ARRAY>
        (?{ [$^R, []] })
        \s*
        \[ \s*
            (?:
      
            (?&VALUE)       (?{ [$^R->[0][0], [$^R->[1]]] })
             (?:,(?&VALUE)       (?{ [$^R->[0][0], [@{$^R->[0][1]}, $^R->[1]]] })
             )* 
              |
              (?:[ ]*) (?{return $^R})
      )?      
        \]
        \s*
    )
  ) 
}xms;

sub parse_json {
    my $source = shift;
    chomp($source);  
    $source =~ s/\\u([0-9a-fA-f]{4})(?{my $qwe ="0x$1";chr(eval $qwe)})/$^R/g; 
    eval { $source =~ m{\A$reg\z}} ; 
    die  if $source =~ /(?:\{(?!\}))/;
    die  if $source =~ /(?:\[(?!\]))/;
    return $source; 
}
1;
