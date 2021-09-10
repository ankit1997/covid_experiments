module CommonUtilsModule

export is_probable

is_probable(p::Float64) = rand() <= p

end