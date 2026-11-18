const ApexChartsGridResize = {
    updated(){
            requestAnimationFrame(() =>{
                    window.dispatchEvent(new Event("resize"))
            })
    }
}
export default ApexChartsGridResize