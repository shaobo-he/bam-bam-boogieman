module Bpl
  module AST
    
    class Declaration
      def is_entrypoint?
        is_a?(ProcedureDeclaration) && attributes.has_key?(:entrypoint)
      end
    end

    class Program
      
      def normalize!
        locate_entrypoints!
        sanity_check
        put_returns_at_the_ends_of_procedures!
        wrap_entrypoint_procedures!
      end
      
      def locate_entrypoints!
        eps = @declarations.select(&:is_entrypoint?)
        
        if eps.empty?
          warn "no entry points found; looking for the usual suspects..."
          eps = @declarations.select do |d|
            d.is_a?(ProcedureDeclaration) && d.name =~ /\bmain\b/i
          end
          eps.each{|d| d.attributes[:entrypoint] = []}
          warn "using entry point#{'s' if eps.count > 1}: #{eps.map(&:name) * ", "}" \
            unless eps.empty?
        end

        abort "no entry points found." if eps.empty?
      end
      
      def sanity_check
        each do |elem| 
          case elem
          when CallStatement
            abort "found call to entry point procedure #{elem.procedure}." \
              if (d = elem.procedure.declaration) && d.is_entrypoint?
          end
        end
      end
      
      def wrap_entrypoint_procedures!
        @declarations.select(&:is_entrypoint?).each do |proc|
          if proc.body then
            proc.body.statements.unshift bpl("assume {:startpoint} true;")
            proc.body.replace do |elem|
              case elem
              when ReturnStatement
                [ bpl("assume {:endpoint} true;"), bpl("return;") ]
              else
                elem
              end
            end
          end
        end

      end
      
      def put_returns_at_the_ends_of_procedures!
        @declarations.each do |d|
          if d.is_a?(ProcedureDeclaration) && d.body &&
            !d.body.statements.last.is_a?(GotoStatement) &&
            !d.body.statements.last.is_a?(ReturnStatement)
            d.body.statements << bpl("return;")
          end
        end
      end
      
    end
  end
end
