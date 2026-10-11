.pragma library

function format(value) {
    var n = Number(value)
    if (!isFinite(n))
        n = 0
    n = Math.round(n)

    var sign = n < 0 ? "-" : ""
    var s = Math.abs(n).toString()
    return sign + s.replace(/\B(?=(\d{3})+(?!\d))/g, ".")
}

function vnd(value) {
    return format(value) + " ₫"
}
