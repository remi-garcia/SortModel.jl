import JuMP.all_constraints
function all_constraints(model::Model)
    cstr = Vector{ConstraintRef}()
    for (F, S) in list_of_constraint_types(model)
        append!(cstr, all_constraints(model, F, S))
    end
    return cstr
end
function all_constraints_affexpr(model::Model)
    cstr = Vector{ConstraintRef}()
    for (F, S) in list_of_constraint_types(model)
        if F == AffExpr
            append!(cstr, all_constraints(model, F, S))
        end
    end
    return cstr
end


import JuMP.add_constraint
function add_constraint(model::Model, set::MOI.LessThan, expr::AffExpr; kwargs...)
    @constraint(model, expr <= set.upper)
    return nothing
end

function add_constraint(model::Model, set::MOI.GreaterThan, expr::AffExpr; to_LessThan::Bool=false)
    if !to_LessThan
        @constraint(model, expr >= set.lower)
    else
        @constraint(model, -expr <= -set.lower)
    end
    return nothing
end

function add_constraint(model::Model, set::MOI.EqualTo, expr::AffExpr; kwargs...)
    @constraint(model, expr == set.value)
    return nothing
end

function add_constraint(model::Model, set::MOI.Interval, expr::AffExpr; kwargs...)
    @constraint(model, expr >= set.lower)
    @constraint(model, expr <= set.upper)
    return nothing
end

# Do not change the index
function add_constraint(model::Model, set::MOI.LessThan, expr::VariableRef; kwargs...)
    set_upper_bound(expr, set.upper)
    return nothing
end
function add_constraint(model::Model, set::MOI.GreaterThan, expr::VariableRef; kwargs...)
    set_lower_bound(expr, set.lower)
    return nothing
end
function add_constraint(model::Model, set::MOI.EqualTo, expr::VariableRef; kwargs...)
    fix(expr, set.value)
    return nothing
end
function add_constraint(model::Model, set::MOI.Interval, expr::VariableRef; kwargs...)
    set_upper_bound(expr, set.upper)
    set_lower_bound(expr, set.lower)
    return nothing
end

# Not used yet
function add_constraint(::Model, ::MOI.ZeroOne, expr::VariableRef; kwargs...)
    set_binary(expr)
    return nothing
end
function add_constraint(::Model, ::MOI.Integer, expr::VariableRef; kwargs...)
    set_integer(expr)
    return nothing
end


function copy_constraint_at_the_end(model::Model, constraint::ConstraintRef; to_LessThan::Bool=false)
    expr = @expression(model, reshape_vector(jump_function(constraint_object(constraint)), shape(constraint_object(constraint))))
    set = reshape_set(moi_set(constraint_object(constraint)), shape(constraint_object(constraint)))
    delete(model, constraint)
    add_constraint(model, set, expr, to_LessThan=to_LessThan)
    return nothing
end

import JuMP.num_variables
function num_variables(expr::AffExpr)::Int
    return length(expr.terms)
end
function num_variables(expr::VariableRef)::Int
    return 1
end
function num_variables(constraint::ConstraintRef)::Int
    return num_variables(@expression(Model(), reshape_vector(jump_function(constraint_object(constraint)), shape(constraint_object(constraint)))))
end

function num_variables_bin(expr::AffExpr)::Int
    return count(==(true), is_binary.(expr.terms.keys))
end
function num_variables_bin(expr::VariableRef)::Int
    return is_binary(expr)
end
function num_variables_bin(constraint::ConstraintRef)::Int
    return num_variables_bin(@expression(Model(), reshape_vector(jump_function(constraint_object(constraint)), shape(constraint_object(constraint)))))
end

function num_variables_int(expr::AffExpr)::Int
    return count(==(true), is_integer.(expr.terms.keys))
end
function num_variables_int(expr::VariableRef)::Int
    return is_integer(expr)
end
function num_variables_int(constraint::ConstraintRef)::Int
    return num_variables_int(@expression(Model(), reshape_vector(jump_function(constraint_object(constraint)), shape(constraint_object(constraint)))))
end

function num_variables_continuous(expr::AffExpr)::Int
    return count(==(true), (.!is_integer.(expr.terms.keys) .& .!is_binary.(expr.terms.keys)))
end
function num_variables_continuous(expr::VariableRef)::Int
    return !is_binary(expr) && !is_integer(expr)
end
function num_variables_continuous(constraint::ConstraintRef)::Int
    return num_variables_continuous(@expression(Model(), reshape_vector(jump_function(constraint_object(constraint)), shape(constraint_object(constraint)))))
end
