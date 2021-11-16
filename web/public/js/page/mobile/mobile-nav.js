function mobileNavInit(){
    const menu = new MmenuLight(document.querySelector('#mobile-menu'), {
        theme: 'dark',
        // selected: 'Selected'
    });
    menu.enable('all'); // '(max-width: 980px)'
    menu.offcanvas({
        // position: 'left',// [| 'right']
        // move: true,// [| false]
        // blockPage: true,// [| false | 'modal']
    });

//	Open the menu.
    document.querySelector('a[href="#menu"]').addEventListener('click', (evnt) => {
        menu.open();

        //	Don't forget to "preventDefault" and to "stopPropagation".
        evnt.preventDefault();
        evnt.stopPropagation();
    });
}
