function toggleType() {
    var type = document.getElementById('keyType').value;
    if (type === 'static') {
        document.getElementById('staticInput').style.display = 'block';
        document.getElementById('dynamicInput').style.display = 'none';
    } else {
        document.getElementById('staticInput').style.display = 'none';
        document.getElementById('dynamicInput').style.display = 'block';
    }
}