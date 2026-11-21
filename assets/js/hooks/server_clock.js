const ServerClock = {
    mounted() {

        const updateClock = () => {
            const now = new Date()

            const hour = String(now.getUTCHours()).padStart(2, "0")
            const minute = String(now.getUTCMinutes()).padStart(2, "0")

            this.el.textContent = `${hour}:${minute}`
            const delay = 60000 - (now.getUTCSeconds() * 1000 + now.getUTCMilliseconds())
        
            this.timer = setTimeout(updateClock, delay)
        }

        updateClock()
    },

    destroyed() {
        clearTimeout(this.timer)
    }
}

export default ServerClock