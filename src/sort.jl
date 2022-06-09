function sort!(model::Model;
               less_variables_first::Bool=false,
               more_variables_first::Bool=false,
               bin_variables_first::Bool=false,
               integer_variables_first::Bool=false,
               continuous_variables_first::Bool=false,
               merge_inequalities::Bool=false,
    )
    #
    constraints = all_constraints_affexpr(model) #AffExpr
    if !less_variables_first && !more_variables_first && !bin_variables_first &&
        !integer_variables_first && !continuous_variables_first
        shuffle!(constraints)
    else
        sort!(constraints, by = x -> (
            bin_variables_first ? min(num_variables(x)-num_variables_bin(x), 0.5) : 0,
            integer_variables_first ? min(num_variables(x)-num_variables_int(x), 0.5) : 0,
            continuous_variables_first ? min(num_variables(x)-num_variables_continuous(x), 0.5) : 0,
            less_variables_first ? num_variables(x) : 0,
            more_variables_first ? -num_variables(x) : 0
        ))
    end

    for constraint in constraints
        copy_constraint_at_the_end(model, constraint, to_LessThan=merge_inequalities)
    end

    return model
end

function sort(model::Model; kwargs...)
    new_model = copy(model)
    sort!(new_model; kwargs...)
    return new_model
end
