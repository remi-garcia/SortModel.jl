function odd(number::Int)
    if number == 0
        return 0
    end
    while mod(number, 2) == 0
        number = div(number, 2)
    end
    return number
end

function get_min_wordlength(number::Int)
    return round(Int, max(log2(odd(abs(number))), 1), RoundUp)
end

function int2bin(number::Int)
    @assert number >= 0
    return reverse(digits(number, base=2))
end

function bin2csd!(vector_bin2csd::Vector{Int})
    @assert issubset(unique(vector_bin2csd), [-1,0,1])
    first_non_zero = 0
    for i in length(vector_bin2csd):-1:1
        if vector_bin2csd[i] != 0
            if first_non_zero == 0
                first_non_zero = i
            end
        elseif first_non_zero - i >= 2
            for j in (i+1):first_non_zero
                vector_bin2csd[j] = 0
            end
            vector_bin2csd[first_non_zero] = -1
            vector_bin2csd[i] = 1
            first_non_zero = i
        else
            first_non_zero = 0
        end
    end
    if first_non_zero > 1
        for j in 1:first_non_zero
            vector_bin2csd[j] = 0
        end
        vector_bin2csd[first_non_zero] = -1
        pushfirst!(vector_bin2csd, 1)
    end

    return vector_bin2csd
end

function bin2csd(vector_bin::Vector{Int})
    @assert issubset(unique(vector_bin), [-1,0,1])
    vector_csd = copy(vector_bin)
    return bin2csd!(vector_csd)
end

function int2csd(number::Int)
    return bin2csd!(int2bin(number))
end

function sum_nonzero(vector_binorcsd::Vector{Int})
    @assert issubset(unique(vector_binorcsd), [-1,0,1])
    sum = 0
    for i in vector_binorcsd
        if i != 0
            sum += 1
        end
    end
    return sum
end

function get_min_number_of_adders(C::Vector{Int})
    oddabsC = sort!(filter!(x -> x > 1, unique!(odd.(abs.(C)))), by=x->sum_nonzero(int2csd(x)))
    if isempty(oddabsC)
        return 0
    end
    if length(oddabsC) == 1
        return round(Int, log2(sum_nonzero(int2csd(oddabsC[1]))), RoundUp)
    end
    return round(Int, log2(sum_nonzero(int2csd(oddabsC[1]))), RoundUp)+sum(max(1, round(Int, log2(sum_nonzero(int2csd(oddabsC[i+1]))/sum_nonzero(int2csd(oddabsC[i]))), RoundUp)) for i in 1:(length(oddabsC)-1))
end

get_min_number_of_adders(C::Int) = get_min_number_of_adders([C])

function get_max_number_of_adders(C::Vector{Int})
    oddabsC = sort!(filter!(x -> x > 1, unique!(odd.(abs.(C)))), by=x->sum_nonzero(int2csd(x)))
    return sum(sum_nonzero(int2csd(val))-1 for val in oddabsC)
end


function set_model!(model::Model, C::Vector{Int};
                    verbose::Bool=false
    )::Model
    oddabsC = sort!(filter!(x -> x > 1, unique!(odd.(abs.(C)))), by=x->sum_nonzero(int2csd(x)))
    NO = length(oddabsC)
    maximum_target = maximum(oddabsC)
    wordlength = round(Int, log2(maximum_target), RoundUp)
    Smin, Smax = -wordlength, wordlength
    maximum_value = 2^wordlength
    known_min_NA = get_min_number_of_adders(C)
    NA = get_max_number_of_adders(C)

    verbose && println("\tBounds on the number of adder: $(known_min_NA)--$(NA)")

    @variable(model, 1 <= ca[0:NA] <= maximum_value-1, Int)
    @constraint(model, [a in 1:known_min_NA], ca[a] >= 3)
    @variable(model, 1 <= ca_no_shift[1:NA] <= maximum_value*2, Int)
    @variable(model, 1 <= cai[1:NA, 1:2] <= maximum_value-1, Int)
    @variable(model, 1 <= cai_left_sh[1:NA] <= maximum_value*2, Int)
    @variable(model, -2*maximum_value <= cai_left_shsg[1:NA] <= maximum_value*2, Int)
    @variable(model, -2*maximum_value <= cai_right_sg[1:NA] <= maximum_value*2, Int)

    @variable(model, Phiai[1:NA, 1:2], Bin)
    @variable(model, caik[a in 1:NA, 1:2, 0:(a-1)], Bin)
    @variable(model, phias[1:NA, 0:Smax], Bin)
    @variable(model, oaj[1:NA, 1:NO], Bin)

    @variable(model, 0 <= force_odd[1:NA] <= maximum_value, Int)
    @variable(model, Psias[1:NA, Smin:0], Bin)

    # C1
    fix(ca[0], 1, force=true)
    # C2 - Modified
    @constraint(model, [a in 1:NA], ca_no_shift[a] == cai_left_shsg[a] + cai_right_sg[a])
    # C3a - C3b
    @constraint(model, [a in 1:NA, i in 1:2, k in 0:(a-1)], cai[a,i] <= ca[k] + (1-caik[a,i,k])*maximum_value)
    @constraint(model, [a in 1:NA, i in 1:2, k in 0:(a-1)], cai[a,i] >= ca[k] - (1-caik[a,i,k])*maximum_value)
    @constraint(model, [a in 1:NA, i in 1:2], sum(caik[a,i,k] for k in 0:(a-1)) == 1)
    # C4a - C4b - Modified
    @constraint(model, [a in 1:NA, s in 0:Smax], cai_left_sh[a] <= 2^s*cai[a,1] + (1-phias[a,s])*2*maximum_value)
    @constraint(model, [a in 1:NA, s in 0:Smax], cai_left_sh[a] >= 2^s*cai[a,1] - (1-phias[a,s])*(2*maximum_value*(2^s)))
    @constraint(model, [a in 1:NA], sum(phias[a,s] for s in 0:Smax) == 1)
    # C5a - C5b - C5c - Modified
    @constraint(model, [a in 1:NA], cai_left_shsg[a] <= cai_left_sh[a] + Phiai[a,1]*2*maximum_value)
    @constraint(model, [a in 1:NA], cai_left_shsg[a] >= cai_left_sh[a] - Phiai[a,1]*(4*maximum_value))
    @constraint(model, [a in 1:NA], cai_left_shsg[a] <= -cai_left_sh[a] + (1-Phiai[a,1])*(4*maximum_value))
    @constraint(model, [a in 1:NA], cai_left_shsg[a] >= -cai_left_sh[a] - (1-Phiai[a,1])*2*maximum_value)
    @constraint(model, [a in 1:NA], cai_right_sg[a] <= cai[a,2] + Phiai[a,2]*maximum_value)
    @constraint(model, [a in 1:NA], cai_right_sg[a] >= cai[a,2] - Phiai[a,2]*(2*maximum_value))
    @constraint(model, [a in 1:NA], cai_right_sg[a] <= -cai[a,2] + (1-Phiai[a,2])*(2*maximum_value))
    @constraint(model, [a in 1:NA], cai_right_sg[a] >= -cai[a,2] - (1-Phiai[a,2])*maximum_value)
    @constraint(model, [a in 1:NA], Phiai[a,1] + Phiai[a,2] <= 1)
    # C6a - C6b
    @constraint(model, [a in 1:NA, j in 1:NO], ca[a] <= oddabsC[j] + (1-oaj[a,j])*maximum_value)
    @constraint(model, [a in 1:NA, j in 1:NO], ca[a] >= oddabsC[j] - (1-oaj[a,j])*maximum_target)
    @constraint(model, [j in 1:NO], sum(oaj[a,j] for a in 1:NA) == 1)

    # Odd
    @constraint(model, [a in 1:NA], ca[a] == 2*force_odd[a]+1)
    @constraint(model, [a in 1:NA, s in Smin:0], ca_no_shift[a] >= 2^(-s)*ca[a] + (Psias[a,s] - 1)*(maximum_value*(2^(-s))))
    @constraint(model, [a in 1:NA, s in Smin:0], ca_no_shift[a] <= 2^(-s)*ca[a] + (1 - Psias[a,s])*(maximum_value*(2^(-s))))
    @constraint(model, [a in 1:NA], sum(Psias[a,s] for s in Smin:0) == 1)
    @constraint(model, [a in 1:NA], phias[a,0] == sum(Psias[a,s] for s in Smin:-1))

    # Fix some variables
    fix(caik[1,1,0], 1, force=true)
    fix(caik[1,2,0], 1, force=true)
    fix(cai[1,1], 1, force=true)
    fix(cai[1,2], 1, force=true)

    if known_min_NA < NA
        @variable(model, used_adder[(known_min_NA+1):NA], Bin)
        if (known_min_NA+2) <= NA
            @constraint(model, [a in (known_min_NA+2):NA], used_adder[a] <= used_adder[a-1])
        end
        @constraint(model, [a in (known_min_NA+1):NA], ca[a] <= used_adder[a]*maximum_value + 1)
        @constraint(model, [a in (known_min_NA+1):NA], ca[a] >= 3*used_adder[a])
        @constraint(model, [a in (known_min_NA+1):NA, i in 1:2], caik[a,i,0] >= 1-used_adder[a])
    end

    @constraint(model, ca[end] <= maximum_target)

    if known_min_NA < NA
        @objective(model, Min, known_min_NA+sum(used_adder))
    else
        # Mock objective
        @objective(model, Min, NA)
    end

    return model
end
